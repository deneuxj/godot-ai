## AIChat - Custom node for generic AI chat interactions.
##
## Maintains conversational history and provides a simple API to send prompts
## and receive responses via signals. Usable in both editor and game.

@tool
extends Node

class_name AIChat


const AIRequestHandler = preload("res://addons/ai_assistant/ai_client/ai_request_handler.gd")
const PromptBuilder = preload("res://addons/ai_assistant/generator/prompt_builder.gd")

signal chat_started()
signal progress(chunks: Array[String])
signal chat_finished(full_response: String)
signal chat_error(error_message: String)
signal status_updated(status: String)


@export_group("API Overrides (Advanced)")

## System prompt to prepend to the conversation.
@export_multiline
var system_prompt: String = PromptBuilder.CHAT_SYSTEM_PROMPT

## API endpoint URL (overrides project settings if not empty).
@export
var api_endpoint: String = ""

## API key for authentication (overrides project settings if not empty).
@export
var api_key: String = ""

## Model name to use (overrides project settings if not empty).
@export
var model: String = ""


@export_group("Tools")

@export
var enable_godot_docs: bool = true

@export
var enable_project_resources: bool = true

@export
var enable_modify_resources: bool = false

@export
var enable_validate_resources: bool = false

@export
var enable_build_scene: bool = true

@export
var use_router: bool = false


# --- State ---

## Current conversation history as an array of message dictionaries:
## [{"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]
@export
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
## Optional [param attachments] can be a list of resource paths (e.g. textures) to include.
func send_message(prompt: String, attachments: Array[String] = []) -> void:
	if _active_handler and _active_handler.is_busy():
		push_warning("AIChat: A request is already in progress. Cancel it first or wait for completion.")
		return

	# 1. Update history with user prompt and attachments.
	var user_content: Variant = prompt
	if not attachments.is_empty():
		var content_array: Array[Dictionary] = []
		content_array.append({"type": "text", "text": prompt})
		
		for path in attachments:
			var res = load(path)
			if res is Texture2D:
				var b64 = PromptBuilder._encode_texture(res)
				if b64:
					content_array.append({
						"type": "image_url",
						"image_url": {"url": "data:image/png;base64," + b64}
					})
			else:
				push_warning("AIChat: Attachment at '%s' is not a supported texture type." % path)
		user_content = content_array

	chat_history.append({"role": "user", "content": user_content})
	partial_response = ""
	
	chat_started.emit()

	# 2. Workload Routing (Optional)
	var final_model := model
	if use_router and final_model.is_empty():
		status_updated.emit("Routing request...")
		var router_model := AISettings.get_string(AISettings.CONN, "router_model")
		if not router_model.is_empty():
			var routing_messages: Array[Dictionary] = [
				{"role": "system", "content": PromptBuilder.ROUTER_SYSTEM_PROMPT},
				{"role": "user", "content": prompt}
			]
			var router_handler := AIRequestHandler.new(self, api_endpoint, api_key, router_model)
			var workload := await router_handler.execute(routing_messages)
			workload = workload.strip_edges().to_lower()
			
			if workload.contains("analyst"):
				final_model = AISettings.get_string(AISettings.CONN, "analyst_model")
				status_updated.emit("Workload: Analyst")
			elif workload.contains("technician"):
				final_model = AISettings.get_string(AISettings.CONN, "technician_model")
				status_updated.emit("Workload: Technician")
			else:
				push_warning("AIChat: Router returned unrecognized workload: " + workload)
				final_model = AISettings.get_string(AISettings.CONN, "model")
			
			# Ensure model is loaded (LM Studio Native)
			if not final_model.is_empty():
				status_updated.emit("Loading model: " + final_model)
				await router_handler.load_model(final_model)
		else:
			push_warning("AIChat: use_router is enabled but ai/connection/router_model is not set.")
			final_model = AISettings.get_string(AISettings.CONN, "model")

	# 3. Vision Capability Check & Payload Stripping
	var tools_handler := AIRequestHandler.new(self, api_endpoint, api_key)
	var vision_ok = await tools_handler.supports_vision(final_model)
	
	var final_messages: Array[Dictionary] = []
	if not system_prompt.is_empty():
		final_messages.append({"role": "system", "content": system_prompt})
	
	for msg in chat_history:
		var new_msg = msg.duplicate()
		if not vision_ok and typeof(new_msg.content) == TYPE_ARRAY:
			# Strip images from multimodal content
			var text_only = ""
			for part in new_msg.content:
				if part.get("type") == "text":
					text_only += part.get("text", "")
			new_msg.content = text_only
		final_messages.append(new_msg)
	
	var tools := PromptBuilder.get_tool_definitions(enable_godot_docs, enable_project_resources, enable_modify_resources, enable_validate_resources, enable_build_scene)

	# 4. Create and configure handler.
	_active_handler = AIRequestHandler.new(self, api_endpoint, api_key, final_model)
	
	# 5. Connect signals.
	_active_handler.progress.connect(func(chunks: Array[String]): 
		for chunk in chunks:
			partial_response += chunk
		progress.emit(chunks)
	)

	# 6. Execute request.
	var response = await _active_handler.execute(final_messages, tools)
	
	# 7. Cleanup and finish.
	if response.is_empty() and not _was_cancelled():
		chat_error.emit("Received empty response from AI.")
		# Fix: Remove last user message from history on error to avoid duplicates on retry
		if not chat_history.is_empty() and chat_history.back().role == "user":
			chat_history.pop_back()
	elif not response.is_empty():
		chat_history.append({"role": "assistant", "content": response})
		partial_response = ""
		chat_finished.emit(response)


## Interrupt the ongoing AI request.
func cancel() -> void:
	if _active_handler:
		_active_handler.cancel()


## Unload the current model (LM Studio Native).
func unload_model(model_id: String = "") -> void:
	var target = model_id
	if target.is_empty():
		target = model if not model.is_empty() else AISettings.get_string(AISettings.CONN, "model")
	
	if not target.is_empty():
		var handler = AIRequestHandler.new(self, api_endpoint, api_key)
		status_updated.emit("Unloading model: " + target)
		await handler.unload_model(target)
		status_updated.emit("Model unloaded")


## Reset the conversation history.
func clear_history() -> void:
	chat_history.clear()


func _was_cancelled() -> bool:
	return _active_handler != null and _active_handler.was_cancelled()
