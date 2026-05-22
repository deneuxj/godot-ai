## AIChat - Custom node for generic AI chat interactions.
##
## Maintains conversational history and provides a simple API to send prompts
## and receive responses via signals. Usable in both editor and game.

@tool
extends Node

class_name AIChat


const AIRequestHandler = preload("res://addons/ai_assistant/ai_client/ai_request_handler.gd")
const PromptBuilder = preload("res://addons/ai_assistant/generator/prompt_builder.gd")
const AISkillNode = preload("res://addons/ai_assistant/skills/ai_skill_node.gd")
const AIClient = preload("res://addons/ai_assistant/ai_client/ai_client.gd")
const AISettings = preload("res://addons/ai_assistant/settings/ai_settings.gd")

signal chat_started()
signal progress(chunks: Array[String])
signal chat_finished(full_response: String)
signal chat_cancelled()
signal chat_error(error_message: String)
signal status_updated(status: String)
signal context_length_updated(tokens: int, characters: int)
signal context_compressed()

## Emitted when the hierarchical TODO stack is modified.
signal todo_list_updated(list: Array[Dictionary])

## Emitted when a new AIRequestHandler is created but before execution.
## Use this to register dynamic tools or apply overrides.
signal request_handler_created(handler: AIRequestHandler)


@export_group("API Overrides (Advanced)")

## System prompt to prepend to the conversation.
@export_multiline
var system_prompt: String = ""

## System prompt override for the Router workload analysis.
@export_multiline
var router_system_prompt: String = ""

## System prompt override for the Analyst workload.
@export_multiline
var analyst_system_prompt: String = ""

## System prompt override for the Technician workload.
@export_multiline
var technician_system_prompt: String = ""

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
var enable_node_hierarchy: bool = true

@export
var enable_todo_list: bool = true

@export
var use_router: bool = false

## If enabled, tool calls and their results are stripped from the history after completion
## to save context space.
@export
var aggressive_compression: bool = false

## List of IDs for skills that should be available in this chat session.
## If empty, all discovered skills are listed.
@export
var active_skills: Array[String] = []


# --- State ---

## Flat list of TODO tasks: [{"text": "...", "done": bool}]
@export
var todo_list: Array[Dictionary] = []:
	set(value):
		todo_list = value
		todo_list_updated.emit(todo_list)
		_mark_dirty()

## The system prompt currently being used for the active request.
var active_system_prompt: String = ""

## Reference to the EditorInterface (injected by the panel).
var editor_interface: EditorInterface = null

## Current conversation history as an array of message dictionaries:
## [{"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]
@export
var chat_history: Array[Dictionary] = []

## Log of routing decisions for debugging: 
## [{"timestamp": "...", "prompt": "...", "raw_response": "...", "decision": "...", "reasoning_on": bool}]
@export
var routing_history: Array[Dictionary] = []

## Map of tool_name -> AITool instance (persists for session)
var session_tools: Dictionary = {}
## IDs of skills that have been activated in this session.
var activated_skill_ids: Array[String] = []

enum ChatStatus {
	IDLE = 0,
	BUSY = 1,
	CANCELLED = 2,
	ERROR = 3,
}

var chat_status: ChatStatus = ChatStatus.IDLE

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

## Toggle this to dump the last sent context to res://.gemini/tmp/last_context.json
@export
var debug_dump_context: bool = false:
	set(value):
		if value:
			dump_context_to_file()
		debug_dump_context = false

## Stores the full message array (including system prompt and tools) sent to the AI.
var last_context: Array[Dictionary] = []
## Stores the tool definitions sent in the last request.
var last_tools: Array[Dictionary] = []


## Send a message to the AI and trigger a streaming response.
## The [param prompt] is appended to the [member chat_history] as a user message.
## Optional [param attachments] can be a list of resource paths (e.g. textures) to include.
func send_message(prompt: String, attachments: Array[String] = []) -> void:
	if chat_status == ChatStatus.BUSY:
		push_warning("AIChat: A request is already in progress. Cancel it first or wait for completion.")
		return

	# 1. Update history with user prompt and attachments.
	var user_content: Variant = prompt
	if not attachments.is_empty():
		var content_array: Array[Dictionary] = []
		content_array.append({"type": "text", "text": prompt})
		
		for path in attachments:
			var res = load(path)
			var tex: Texture2D = null
			
			if res is Texture2D:
				tex = res
			else:
				# Try loading as image directly if load() fails (common for temporary files)
				var img = Image.load_from_file(path)
				if img:
					tex = ImageTexture.create_from_image(img)
			
			if tex:
				var b64 = PromptBuilder._encode_texture(tex)
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
	chat_status = ChatStatus.BUSY
	
	_update_context_length()
	
	# REQ-CHAT-0013, REQ-CHAT-0014: Context Compression
	if not compress_context():
		push_warning("AIChat: Context limit reached even after compression. The AI provider may reject the request.")

	chat_started.emit()

	# 2. Workload Routing (Optional)
	var final_model := model
	active_system_prompt = system_prompt
	var final_reasoning := ""
	
	if use_router and final_model.is_empty():
		status_updated.emit("Processing...")
		var router_model := AISettings.get_string(AISettings.CONN, "router_model")
		if not router_model.is_empty():
			var routing_messages: Array[Dictionary] = [
				{"role": "system", "content": PromptBuilder.get_router_prompt(router_system_prompt)}
			]
			
			var filtered_history: Array[Dictionary] = []
			for msg in chat_history:
				if msg.role == "tool" or msg.has("tool_calls"):
					continue
				
				var new_msg = msg.duplicate()
				var content = new_msg.get("content")
				if typeof(content) == TYPE_ARRAY:
					# Strip images from multimodal content for routing
					var text_only = ""
					for part in content:
						if part.get("type") == "text":
							text_only += part.get("text", "")
					new_msg.content = text_only
				filtered_history.append(new_msg)
			
			# Present the context as a single text block to keep the router in an observer role
			var presentation := "[TRANSCRIPT_START]\n"
			var slice_start = max(0, filtered_history.size() - 6)
			for i in range(slice_start, filtered_history.size()):
				var msg = filtered_history[i]
				presentation += "%s: %s\n" % [msg.role.to_upper(), msg.get("content", "")]
			presentation += "[TRANSCRIPT_END]\n\n"
			presentation += "Decision:"

			routing_messages.append({"role": "user", "content": presentation})

			var router_handler := AIRequestHandler.new(self, api_endpoint, api_key, router_model)
			router_handler.prompt_provider = PromptBuilder.create_simple_provider(PromptBuilder.get_router_prompt(router_system_prompt))
			router_handler.max_tokens = 64 # Small response for routing

			router_handler.mock_client = mock_client
			_active_handler = router_handler

			# Ensure router model is loaded
			await router_handler.load_model(router_model)
			if chat_status == ChatStatus.CANCELLED:
				_cleanup_after_cancel(router_handler)
				return

			var workload_raw := await router_handler.execute(routing_messages)
			if chat_status == ChatStatus.CANCELLED:
				_cleanup_after_cancel(router_handler)
				return

			var workload = workload_raw.strip_edges().to_lower()

			# Default to technician if the router is silent or confused
			if workload.is_empty():
				workload = "technician"

			var reasoning_val := ""
			if workload.contains(":on"):
				reasoning_val = "on"
				workload = workload.replace(":on", "")

			# Log the routing decision
			routing_history.append({
				"timestamp": Time.get_datetime_string_from_system(),
				"prompt": presentation.strip_edges(),
				"raw_response": workload_raw,
				"decision": workload,
				"reasoning_on": not reasoning_val.is_empty()
			})

			if workload.contains("analyst"):

				final_model = AISettings.get_string(AISettings.CONN, "analyst_model")
				active_system_prompt = PromptBuilder.get_analyst_prompt(analyst_system_prompt)

				# REQ-LMSTUDIO-0004: Set analyst reasoning to "off" by default for Qwen.
				if reasoning_val.is_empty():
					reasoning_val = "off"

				status_updated.emit("Thinking...")
			elif workload.contains("technician"):
				final_model = AISettings.get_string(AISettings.CONN, "technician_model")
				active_system_prompt = PromptBuilder.get_technician_prompt(technician_system_prompt)

				# Disable reasoning for technician to avoid formatting issues (XML/stop) with Qwen
				reasoning_val = "off"

				status_updated.emit("Implementing...")
			else:
				push_warning("AIChat: Router returned unrecognized or empty workload. Defaulting to base model. Response: '" + workload_raw + "'")
				final_model = AISettings.get_string(AISettings.CONN, "model")

				if final_model.is_empty():
					final_model = AISettings.get_string(AISettings.CONN, "technician_model")
			
			# Ensure model is loaded (LM Studio Native)
			if not final_model.is_empty():
				# We don't want to overwrite the "Thinking/Implementing" status with "Loading model"
				# unless it's actually doing a REST call that takes time.
				# For now, let's keep the user intent status.
				await router_handler.load_model(final_model)
				if chat_status == ChatStatus.CANCELLED:
					_cleanup_after_cancel(router_handler)
					return
			
			final_reasoning = reasoning_val
			_active_handler = null
		else:
			push_warning("AIChat: use_router is enabled but ai/connection/router_model is not set.")
			final_model = AISettings.get_string(AISettings.CONN, "model")

	# 3. Vision Capability Check & Payload Stripping
	var tools_handler := AIRequestHandler.new(self, api_endpoint, api_key)
	tools_handler.mock_client = mock_client
	_active_handler = tools_handler
	var vision_ok = await tools_handler.supports_vision(final_model)
	if chat_status == ChatStatus.CANCELLED:
		_cleanup_after_cancel(tools_handler)
		return
	_active_handler = null
	
	var final_messages: Array[Dictionary] = []
	var base_system_prompt := PromptBuilder.get_chat_prompt(active_system_prompt)
	
	# Add skills discovery context to the system prompt
	var discovered_skills = _discover_active_skills()
	var skills_context = PromptBuilder.get_skills_discovery_context(discovered_skills)
	var todo_context = PromptBuilder._get_todo_context(todo_list)
		
	final_messages.append({
		"role": "system", 
		"content": base_system_prompt + PromptBuilder.get_environment_context() + skills_context + todo_context
	})
	
	for msg in chat_history:
		var new_msg = msg.duplicate()
		var content = new_msg.get("content")
		if not vision_ok and typeof(content) == TYPE_ARRAY:
			# Strip images from multimodal content
			var text_only = ""
			for part in content:
				if part.get("type") == "text":
					text_only += part.get("text", "")
			new_msg.content = text_only
		final_messages.append(new_msg)
	
	final_messages = PromptBuilder.sanitize_history(final_messages)
	
	var tools := get_current_tool_definitions()

	# 4. Create and configure handler.
	if not use_router or model != "":
		status_updated.emit("Generating...")
	
	var handler := AIRequestHandler.new(self, api_endpoint, api_key, final_model)
	handler.prompt_provider = PromptBuilder.create_chat_provider(self)
	
	# Disable reasoning if using tools and model is likely Qwen (lm-studio or local-model)
	if not tools.is_empty() and (final_model.to_lower().contains("qwen") or api_endpoint.contains("localhost") or api_endpoint.is_empty()):
		handler.reasoning = "off"
	else:
		handler.reasoning = final_reasoning
		
	handler.mock_client = mock_client
	_active_handler = handler
	
	# Sync session state to handler
	handler._active_tools = session_tools
	handler._activated_skill_ids = activated_skill_ids
	
	# DEBUG: Store initial context
	last_context = final_messages
	last_tools = tools
	
	request_handler_created.emit(handler)
	
	# 5. Connect signals.
	handler.progress.connect(func(chunks: Array[String]): 
		for chunk in chunks:
			partial_response += chunk
		progress.emit(chunks)
	)

	# 6. Execute request.
	var response = await handler.execute(final_messages, tools)
	
	# Update last_context with all messages including tool results
	last_context = final_messages.duplicate()
	for msg in handler.new_messages:
		last_context.append(msg)
	
	# 7. Cleanup and finish.
	if chat_status == ChatStatus.CANCELLED:
		_cleanup_after_cancel(handler)
		return
		
	# Append all new messages (tool calls, tool results, and final assistant text)
	for msg in handler.new_messages:
		chat_history.append(msg)
	
	if response.is_empty() and not handler.tools_invoked:
		chat_status = ChatStatus.ERROR
		chat_error.emit("Received empty response from AI.")
		# Fix: Remove last user message from history on error to avoid duplicates on retry
		if not chat_history.is_empty() and chat_history.back().role == "user":
			chat_history.pop_back()
	else:
		# Sync back activated skills/tools
		session_tools = handler._active_tools
		activated_skill_ids = handler._activated_skill_ids
		
		partial_response = ""
		chat_status = ChatStatus.IDLE
		chat_finished.emit(response)
		
		# --- Agentic Hand-off for Viewport Capture ---
		# If capture_editor_view was successfully called, automatically trigger a follow-up
		var capture_successful = false
		for msg in handler.new_messages:
			if msg.get("role") == "tool" and msg.get("name") == "capture_editor_view":
				if not str(msg.get("content")).begins_with("Error"):
					capture_successful = true
					break
			
		if capture_successful:
			var img_path = "res://.gemini/tmp/snapshot.jpg"
			if FileAccess.file_exists(img_path):
				print("AIChat: Capture detected. Triggering agentic hand-off...")
				# We wait a bit to ensure the UI has processed the previous turn signals
				await get_tree().process_frame
				# We send a follow-up message from the system (acting as user)
				send_message("The snapshot you requested is now attached. Please analyze it.", [img_path])
	
	_update_context_length()
	
	if _active_handler == handler:
		_active_handler = null


func _cleanup_after_cancel(handler: AIRequestHandler = null) -> void:
	if handler:
		# 1. Save any completed tool interactions first to maintain order
		for msg in handler.new_messages:
			chat_history.append(msg)
	
	# 2. Save partial response or ensure role alternation
	if not partial_response.is_empty():
		if not chat_history.is_empty() and chat_history.back().role == "assistant":
			# If the last message is already assistant, it means it's a fallback 
			# or an empty message from the handler. We replace its content with partial.
			chat_history.back().content = partial_response
		else:
			chat_history.append({"role": "assistant", "content": partial_response})
		partial_response = ""
	elif not chat_history.is_empty() and chat_history.back().role == "tool":
		# REQ-CHAT-0016: Always end with assistant if tools were called
		chat_history.append({"role": "assistant", "content": "..."})
	
	_update_context_length()
	if _active_handler == handler:
		_active_handler = null
	
	# chat_status is already CANCELLED, keep it for UI
	chat_cancelled.emit()


## Interrupt the ongoing AI request.
func cancel() -> void:
	if chat_status == ChatStatus.BUSY:
		chat_status = ChatStatus.CANCELLED
		if _active_handler:
			_active_handler.cancel()
		else:
			# If no handler is active, we might still be in an await point or just started.
			# We emit it here to ensure the UI is notified immediately.
			chat_cancelled.emit()


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


## Reset the conversation history and all session state (including skills).
func clear_history() -> void:
	chat_history.clear()
	routing_history.clear()
	activated_skill_ids.clear()
	session_tools.clear()
	todo_list = []
	_update_context_length()


## Returns the last sent context (messages + tools) as a formatted JSON string.
func get_last_context_json() -> String:
	var messages := last_context.duplicate()
	
	if chat_status == ChatStatus.BUSY and _active_handler:
		# Append completed tool loops during the active request
		for msg in _active_handler.new_messages:
			messages.append(msg)
		
		# Append the ongoing text chunk if any
		if not partial_response.is_empty():
			messages.append({"role": "assistant", "content": partial_response})
			
	var data := {
		"messages": messages,
		"tools": last_tools,
		"routing_history": routing_history,
		"model": model,
		"api_endpoint": api_endpoint
	}
	return JSON.stringify(data, "\t")


## Dumps the last context to a file for debugging.
func dump_context_to_file() -> void:
	var dir := "res://.gemini/tmp"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	
	var path := dir + "/last_context.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(get_last_context_json())
		file.close()
		print("AIChat: Context dumped to " + path)
	else:
		push_error("AIChat: Failed to open file for context dump: " + path)


## Explicitly activate a skill for this session.
func activate_skill(skill_name: String) -> String:
	if not _active_handler:
		_active_handler = AIRequestHandler.new(self, api_endpoint, api_key, model)
		_active_handler.prompt_provider = PromptBuilder.create_chat_provider(self)
		_active_handler.mock_client = mock_client
		_active_handler._active_tools = session_tools
		_active_handler._activated_skill_ids = activated_skill_ids
		
	var result = await _active_handler.activate_skill(skill_name)
	
	# Sync back
	session_tools = _active_handler._active_tools
	activated_skill_ids = _active_handler._activated_skill_ids
	
	return result


## Returns true if a request is currently active.
func is_busy() -> bool:
	return chat_status == ChatStatus.BUSY


func get_current_tool_definitions() -> Array[Dictionary]:
	return PromptBuilder.get_tool_definitions(
		enable_godot_docs, 
		enable_project_resources, 
		enable_modify_resources, 
		enable_validate_resources, 
		enable_execute_script, 
		enable_capture_view,
		enable_node_hierarchy,
		enable_todo_list
	)


## Returns the current conversational context length.
## Returns a dictionary with "tokens" (estimate) and "characters" keys.
func get_context_length() -> Dictionary:
	var total_chars := 0
	
	# Add system prompt length (following hierarchy)
	var active_prompt = PromptBuilder.get_chat_prompt(system_prompt)
	total_chars += active_prompt.length()
	
	# Add environment context
	total_chars += PromptBuilder.get_environment_context().length()
	
	# Add TODO stack context
	total_chars += PromptBuilder._get_todo_context(todo_list).length()
	
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
	
	var pruned := false
	
	# REQ-CHAT-0015: Aggressive Compression
	if aggressive_compression:
		var i := 0
		while i < chat_history.size():
			var msg = chat_history[i]
			var removed := false
			
			if msg.role == "tool":
				chat_history.remove_at(i)
				removed = true
				pruned = true
			elif msg.role == "assistant" and msg.has("tool_calls"):
				if msg.get("content", "").is_empty():
					chat_history.remove_at(i)
					removed = true
					pruned = true
				else:
					# Keep the content but remove the tool calls
					var new_msg = msg.duplicate()
					new_msg.erase("tool_calls")
					chat_history[i] = new_msg
					pruned = true
			
			if not removed:
				i += 1
		
	if limit <= 0 and not force: 
		if pruned:
			context_compressed.emit()
			_update_context_length()
		return true # No limit set
	
	var current := get_context_length()
	if not force and current.tokens <= limit:
		if pruned:
			context_compressed.emit()
			_update_context_length()
		return true
	
	# REQ-CHAT-0013: Intelligent pruning
	# 1. Prune old tool interactions and successful correction cycles.
	# We keep the first 2 messages (Initial Task Spec) and last 5 messages (Current Context).
	var i := 2
	while i < chat_history.size() - 5:
		var msg = chat_history[i]
		
		var is_prunable := false
		if msg.role == "tool" or msg.has("tool_calls"):
			is_prunable = true
		elif msg.role == "user" and str(msg.get("content", "")).contains("failed validation"):
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
	_mark_dirty()


func _mark_dirty() -> void:
	if Engine.is_editor_hint() and editor_interface:
		editor_interface.mark_scene_as_dirty()
		notify_property_list_changed()


func _discover_active_skills() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	_scan_for_skills(self, result)
	return result


func _scan_for_skills(node: Node, result: Array[Dictionary]) -> void:
	for child in node.get_children():
		if child is AISkillNode and child.is_active:
			# Respect active_skills filter if set
			if not active_skills.is_empty() and not active_skills.has(child.name):
				continue
				
			result.append({
				"name": child.name,
				"description": child.description
			})
		_scan_for_skills(child, result)
