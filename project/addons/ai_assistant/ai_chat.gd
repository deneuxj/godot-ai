## AIChat - Custom node for generic AI chat interactions.
##
## Maintains conversational history and provides a simple API to send prompts
## and receive responses via signals. Usable in both editor and game.

@tool
extends Node

class_name AIChat


const AIRequestHandler = preload("res://addons/ai_assistant/ai_client/ai_request_handler.gd")

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

var _active_handler: AIRequestHandler = null


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
	if _active_handler and _active_handler.is_busy():
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

	# 3. Create and configure handler.
	_active_handler = AIRequestHandler.new(self, api_endpoint, api_key, model)
	
	# 4. Connect signals.
	_active_handler.progress.connect(func(chunks: Array[String]): 
		for chunk in chunks:
			partial_response += chunk
		progress.emit(chunks)
	)

	# 5. Execute request.
	var response = await _active_handler.execute(messages)
	
	# 6. Cleanup and finish.
	if response.is_empty() and not _was_cancelled():
		chat_error.emit("Received empty response from AI.")
	elif not response.is_empty():
		chat_history.append({"role": "assistant", "content": response})
		partial_response = ""
		chat_finished.emit(response)


## Interrupt the ongoing AI request.
func cancel() -> void:
	if _active_handler:
		_active_handler.cancel()


## Reset the conversation history.
func clear_history() -> void:
	chat_history.clear()


func _was_cancelled() -> bool:
	return _active_handler != null and _active_handler.was_cancelled()
