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
signal context_length_updated(tokens: int, characters: int)
signal context_compressed()


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
var enable_execute_script: bool = true

@export
var enable_capture_view: bool = true

@export
var use_router: bool = false


# --- State ---

## Reference to the EditorInterface (injected by the panel).
var editor_interface: EditorInterface = null

## Current conversation history as an array of message dictionaries:
## [{"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]
@export
var chat_history: Array[Dictionary] = []

## The partial response currently being received from the AI.
## This is cleared when a new request starts and populated during streaming.
var partial_response: String = ""

var _active_handler: AIRequestHandler = null

## Optional mock client for testing.
var mock_client: AIClient = null


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
	
	_update_context_length()
	
	# REQ-CHAT-0013, REQ-CHAT-0014: Context Compression
	if not compress_context():
		push_warning("AIChat: Context limit reached even after compression. The AI provider may reject the request.")

	chat_started.emit()

	# 2. Workload Routing (Optional)
	var final_model := model
	var active_system_prompt := system_prompt
	
	if use_router and final_model.is_empty():
		status_updated.emit("Processing...")
		var router_model := AISettings.get_string(AISettings.CONN, "router_model")
		if not router_model.is_empty():
			var routing_messages: Array[Dictionary] = [
				{"role": "system", "content": PromptBuilder.ROUTER_SYSTEM_PROMPT},
				{"role": "user", "content": prompt}
			]
			var router_handler := AIRequestHandler.new(self, api_endpoint, api_key, router_model)
			router_handler.mock_client = mock_client
			var workload := await router_handler.execute(routing_messages)
			workload = workload.strip_edges().to_lower()
			
			if workload.contains("analyst"):
				final_model = AISettings.get_string(AISettings.CONN, "analyst_model")
				active_system_prompt = PromptBuilder.ANALYST_SYSTEM_PROMPT
				status_updated.emit("Thinking...")
			elif workload.contains("technician"):
				final_model = AISettings.get_string(AISettings.CONN, "technician_model")
				active_system_prompt = PromptBuilder.TECHNICIAN_SYSTEM_PROMPT
				status_updated.emit("Implementing...")
			else:
				push_warning("AIChat: Router returned unrecognized workload: " + workload)
				final_model = AISettings.get_string(AISettings.CONN, "model")
			
			# Ensure model is loaded (LM Studio Native)
			if not final_model.is_empty():
				# We don't want to overwrite the "Thinking/Implementing" status with "Loading model"
				# unless it's actually doing a REST call that takes time.
				# For now, let's keep the user intent status.
				await router_handler.load_model(final_model)
		else:
			push_warning("AIChat: use_router is enabled but ai/connection/router_model is not set.")
			final_model = AISettings.get_string(AISettings.CONN, "model")

	# 3. Vision Capability Check & Payload Stripping
	var tools_handler := AIRequestHandler.new(self, api_endpoint, api_key)
	tools_handler.mock_client = mock_client
	var vision_ok = await tools_handler.supports_vision(final_model)
	
	var final_messages: Array[Dictionary] = []
	var base_system_prompt := active_system_prompt
	if base_system_prompt.is_empty():
		base_system_prompt = PromptBuilder.CHAT_SYSTEM_PROMPT
		
	final_messages.append({
		"role": "system", 
		"content": base_system_prompt + PromptBuilder.get_environment_context()
	})
	
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
	
	var tools := get_current_tool_definitions()

	# 4. Create and configure handler.
	if not use_router or model != "":
		status_updated.emit("Generating...")
	
	_active_handler = AIRequestHandler.new(self, api_endpoint, api_key, final_model)
	_active_handler.mock_client = mock_client
	
	# 5. Connect signals.
	_active_handler.progress.connect(func(chunks: Array[String]): 
		for chunk in chunks:
			partial_response += chunk
		progress.emit(chunks)
	)

	# 6. Execute request.
	var response = await _active_handler.execute(final_messages, tools)
	
	# 7. Cleanup and finish.
	if not _was_cancelled():
		# Append all new messages (tool calls, tool results, and final assistant text)
		for msg in _active_handler.new_messages:
			chat_history.append(msg)
		
		if response.is_empty() and not _active_handler.tools_invoked:
			chat_error.emit("Received empty response from AI.")
			# Fix: Remove last user message from history on error to avoid duplicates on retry
			if not chat_history.is_empty() and chat_history.back().role == "user":
				chat_history.pop_back()
		else:
			partial_response = ""
			chat_finished.emit(response)
		
		_update_context_length()


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
	_update_context_length()


func _was_cancelled() -> bool:
	return _active_handler != null and _active_handler.was_cancelled()


func get_current_tool_definitions() -> Array[Dictionary]:
	return PromptBuilder.get_tool_definitions(
		enable_godot_docs, 
		enable_project_resources, 
		enable_modify_resources, 
		enable_validate_resources, 
		enable_execute_script, 
		enable_capture_view
	)


## Returns the current conversational context length.
## Returns a dictionary with "tokens" (estimate) and "characters" keys.
func get_context_length() -> Dictionary:
	var total_chars := 0
	
	# Add system prompt length
	var active_prompt = system_prompt
	if active_prompt.is_empty():
		active_prompt = PromptBuilder.CHAT_SYSTEM_PROMPT
	total_chars += active_prompt.length()
	
	# Add environment context
	total_chars += PromptBuilder.get_environment_context().length()
	
	# Add tool definitions length
	var tools = get_current_tool_definitions()
	for t in tools:
		total_chars += JSON.stringify(t).length()
	
	# Add history length
	for msg in chat_history:
		total_chars += _get_message_length(msg)
	
	# Tokens are roughly 4 characters each.
	return {
		"tokens": int(ceil(total_chars / 4.0)),
		"characters": total_chars
	}


## Surgically prunes the conversation history to stay within token limits.
## If [param force] is true, it will prune as much as possible regardless of current length.
## Returns true if the context is within limits after compression.
func compress_context(force: bool = false) -> bool:
	var limit := AISettings.get_int(AISettings.GEN, "context_limit")
	# print("Compressing context. Limit: %d, Current: %d" % [limit, get_context_length().tokens])
	if limit <= 0 and not force: return true # No limit set
	
	var current := get_context_length()
	if not force and current.tokens <= limit:
		return true
	
	var pruned := false
	
	# REQ-CHAT-0013: Intelligent pruning
	# 1. Prune old tool interactions and successful correction cycles.
	# We keep the first 2 messages (Initial Task Spec) and last 5 messages (Current Context).
	var i := 2
	while i < chat_history.size() - 5:
		var msg = chat_history[i]
		
		var is_prunable := false
		if msg.role == "tool" or msg.has("tool_calls"):
			is_prunable = true
		elif msg.role == "user" and str(msg.content).contains("failed validation"):
			# This is part of an error correction loop. 
			# If we have reached this point and are still going, we might be able to prune old ones.
			is_prunable = true
		
		if is_prunable:
			chat_history.remove_at(i)
			pruned = true
			if get_context_length().tokens <= limit:
				break
			continue # Don't increment i
		i += 1
	
	# 2. If still over limit, remove oldest non-vital messages (after task spec).
	while chat_history.size() > 7 and get_context_length().tokens > limit:
		chat_history.remove_at(2)
		pruned = true
	
	if pruned:
		context_compressed.emit()
		_update_context_length()
	
	return get_context_length().tokens <= limit


func _get_message_length(msg: Dictionary) -> int:
	var total_len := 0
	
	# 1. Standard content
	var content = msg.get("content", "")
	if content is String:
		total_len += content.length()
	elif content is Array:
		for part in content:
			if part.get("type") == "text":
				total_len += part.get("text", "").length()
	
	# 2. Tool calls (AI side)
	if msg.has("tool_calls"):
		total_len += JSON.stringify(msg["tool_calls"]).length()
		
	# 3. Tool call ID (Tool side results)
	if msg.has("tool_call_id"):
		total_len += str(msg["tool_call_id"]).length()
		
	# 4. Name (used in tool responses)
	if msg.has("name"):
		total_len += str(msg["name"]).length()
		
	return total_len


func _update_context_length() -> void:
	var length := get_context_length()
	context_length_updated.emit(length.tokens, length.characters)
