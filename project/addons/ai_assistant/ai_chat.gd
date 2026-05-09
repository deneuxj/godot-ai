## AIChat - Custom node for generic AI chat interactions.
##
## Maintains conversational history and provides a simple API to send prompts
## and receive responses via signals. Usable in both editor and game.

@tool
extends Node

class_name AIChat

const AISettings = preload("res://addons/ai_assistant/settings/ai_settings.gd")


signal chat_started()
signal progress(chunks: Array[String])
signal chat_finished(full_response: String)
signal chat_error(error_message: String)


@export_group("API Overrides (Advanced)")

## System prompt to prepend to the conversation.
@export_multiline
var system_prompt: String = ""

## API endpoint URL (overrides project settings if not empty).
@export
var api_endpoint: String = ""

## API key for authentication (overrides project settings if not empty).
@export
var api_key: String = ""

## Model name to use (overrides project settings if not empty).
@export
var model: String = ""


# --- State ---

## Current conversation history as an array of message dictionaries:
## [{"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]
var chat_history: Array[Dictionary] = []

## The partial response currently being received from the AI.
## This is cleared when a new request starts and populated during streaming.
var partial_response: String = ""

var _active_client: AIClient = null


@export_group("Debug / Testing")

## A prompt to send for testing purposes.
@export_multiline
var debug_prompt: String = ""

## Toggle this to send the [member debug_prompt].
@export
var debug_send: bool = false:
	set(value):
		if value:
			if not debug_prompt.is_empty():
				send_message(debug_prompt)
			else:
				push_warning("AIChat: debug_prompt is empty.")
		debug_send = false

## Toggle this to clear the history.
@export
var debug_clear_history: bool = false:
	set(value):
		if value:
			clear_history()
			print("AIChat: History cleared.")
		debug_clear_history = false


## Send a message to the AI and trigger a streaming response.
## The [param prompt] is appended to the [member chat_history] as a user message.
func send_message(prompt: String) -> void:
	if is_instance_valid(_active_client):
		push_warning("AIChat: A request is already in progress. Cancel it first or wait for completion.")
		return

	# 1. Update history with user prompt.
	chat_history.append({"role": "user", "content": prompt})
	partial_response = ""
	
	chat_started.emit()

	# 2. Prepare full message list for the API.
	var messages: Array[Dictionary] = []
	if not system_prompt.is_empty():
		messages.append({"role": "system", "content": system_prompt})
	messages.append_array(chat_history)

	# 3. Create and configure client.
	var client := AIClient.create_openai_client()
	add_child(client)
	_active_client = client

	var endpoint: String = api_endpoint if not api_endpoint.is_empty() else AISettings.get_string(AISettings.CONN, "base_url")
	var key: String = api_key if not api_key.is_empty() else AISettings.get_string(AISettings.CONN, "api_key")
	var model_name: String = model if not model.is_empty() else AISettings.get_string(AISettings.CONN, "model")
	var max_tokens: int = AISettings.get_int(AISettings.GEN, "max_tokens")

	client.set_endpoint(endpoint)
	if not key.is_empty():
		client.set_api_key(key)
	if not model_name.is_empty():
		client.set_model(model_name)
	client.set_max_tokens(max_tokens)

	# 4. Connect signals.
	client.progress.connect(func(chunks: Array[String]): 
		for chunk in chunks:
			partial_response += chunk
		progress.emit(chunks)
	)

	# 5. Execute request.
	var response = await client.chat_stream(messages)
	
	# 6. Cleanup and finish.
	if is_instance_valid(client):
		client.queue_free()
	
	if _active_client == client:
		_active_client = null

	if response.is_empty() and not _was_cancelled(client):
		chat_error.emit("Received empty response from AI.")
	elif not response.is_empty():
		chat_history.append({"role": "assistant", "content": response})
		partial_response = ""
		chat_finished.emit(response)


## Interrupt the ongoing AI request.
func cancel() -> void:
	if is_instance_valid(_active_client):
		_active_client.cancel()
		# _active_client will be cleaned up in the await loop of send_message.


## Reset the conversation history.
func clear_history() -> void:
	chat_history.clear()


func _was_cancelled(client: AIClient) -> bool:
	# This is a heuristic since AIClient doesn't explicitly track cancel state yet.
	# If we are here and response is empty, it's likely an error or cancel.
	return _active_client == null or not is_instance_valid(client)
