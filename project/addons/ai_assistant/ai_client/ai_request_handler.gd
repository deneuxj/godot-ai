## AIRequestHandler - Shared helper for executing AI requests.
##
## Encapsulates the lifecycle of an AI request, including client creation,
## configuration (with overrides), signal forwarding, and cleanup.

class_name AIRequestHandler
extends RefCounted

const AISettings = preload("res://addons/ai_assistant/settings/ai_settings.gd")

## Emitted when streaming chunks arrive.
signal progress(chunks: Array[String])

var _parent: Node
var _active_client: AIClient = null
var _cancelled: bool = false

## Map of tool_name -> AITool instance
var _active_tools: Dictionary = {}
## IDs of skills that have been activated in this session.
var _activated_skill_ids: Array[String] = []

## True if any tool was called during the last execute() call.
var tools_invoked: bool = false

## All new messages (assistant and tool) added during the last execute() call.
var new_messages: Array[Dictionary] = []

## API endpoint URL override.
var api_endpoint: String = ""
## API key override.
var api_key: String = ""
## Model name override.
var model: String = ""

## If set, this client will be used instead of creating a real one.
var mock_client: AIClient = null


func _init(parent: Node, endpoint: String = "", key: String = "", model_name: String = "") -> void:
	_parent = parent
	api_endpoint = endpoint
	api_key = key
	model = model_name


## Send a streaming chat request and return the full response.
func execute(messages: Array[Dictionary], tools: Array[Dictionary] = []) -> String:
	if is_busy():
		push_warning("AIRequestHandler: A request is already in progress.")
		return ""
	
	if not is_instance_valid(_parent):
		push_error("AIRequestHandler: Parent node is invalid.")
		return ""

	_cancelled = false

	# 1. Create client and configure with defaults.
	var client: AIClient = null
	
	if mock_client:
		client = mock_client
	else:
		# Auto-detection of LM Studio
		var endpoint_to_check = api_endpoint if not api_endpoint.is_empty() else AISettings.get_string(AISettings.CONN, "base_url")
		if not mock_client and await _is_lm_studio(endpoint_to_check):

			client = load("res://addons/ai_assistant/ai_client/lm_studio_client.gd").new()
			print("AIRequestHandler: LM Studio detected. Using LMStudioClient.")
		else:
			client = AIClient.create_openai_client()
	
	if not client.is_inside_tree():
		_parent.add_child(client)
	_active_client = client

	# 2. Apply Overrides.
	if not api_endpoint.is_empty():
		client.set_endpoint(api_endpoint)
	if not api_key.is_empty():
		client.set_api_key(api_key)
	if not model.is_empty():
		client.set_model(model)
	
	# Ensure max_tokens is fresh from AISettings.
	client.set_max_tokens(AISettings.get_int(AISettings.GEN, "max_tokens"))

	# 3. Connect signals.
	client.progress.connect(func(chunks: Array[String]):
		progress.emit(chunks)
	)

	# 4. Execute request loop (handles tool calls)
	var final_response: String = ""
	var current_messages = messages.duplicate()
	tools_invoked = false
	new_messages.clear()
	
	# Prepare the full list of tools (passed ones + dynamically registered ones)
	var all_tools = tools.duplicate()
	for tool_instance in _active_tools.values():
		var found = false
		for t in all_tools:
			if t.function.name == tool_instance.name:
				found = true
				break
		if not found:
			all_tools.append(tool_instance.get_definition())
	
	const MAX_TOOL_LOOPS = 5
	for i in range(MAX_TOOL_LOOPS):
		var result = await client.chat_stream(current_messages, all_tools)
		
		if _cancelled:
			break
			
		if typeof(result) == TYPE_DICTIONARY and result.has("tool_calls"):
			tools_invoked = true
			var tool_calls = result["tool_calls"]
			# Add the assistant message with tool calls to history
			var assistant_msg = {
				"role": "assistant",
				"tool_calls": tool_calls
			}
			if result.has("content") and not str(result["content"]).is_empty():
				assistant_msg["content"] = result["content"]
				
			current_messages.append(assistant_msg)
			new_messages.append(assistant_msg)
			
			# Execute each tool call
			for tool_call in tool_calls:
				var tool_result = await _execute_tool(tool_call)
				var tool_msg = {
					"role": "tool",
					"tool_call_id": tool_call.id,
					"name": tool_call.function.name,
					"content": tool_result
				}
				current_messages.append(tool_msg)
				new_messages.append(tool_msg)
				
				# If activate_skill was called, we might have new tools for the NEXT turn
				if tool_call.function.name == "activate_skill":
					for tool_instance in _active_tools.values():
						var found = false
						for t in all_tools:
							if t.function.name == tool_instance.name:
								found = true
								break
						if not found:
							all_tools.append(tool_instance.get_definition())
			
			# Continue loop to send tool results back to AI
			continue
		else:
			final_response = str(result)
			if not final_response.is_empty():
				var final_msg = {"role": "assistant", "content": final_response}
				current_messages.append(final_msg)
				new_messages.append(final_msg)
			break

	# 5. Cleanup.
	if is_instance_valid(client) and not mock_client:
		client.queue_free()
	
	if _active_client == client:
		_active_client = null
	
	return final_response


func _is_lm_studio(url: String) -> bool:
	var check_url = url + "/api/v1/models"
	var http := HTTPRequest.new()
	_parent.add_child(http)
	
	var headers: PackedStringArray = ["Content-Type: application/json"]
	var key_to_use = api_key if not api_key.is_empty() else AISettings.get_string(AISettings.CONN, "api_key")
	if not key_to_use.is_empty():
		headers.append("Authorization: Bearer " + key_to_use)
	
	var error := http.request(check_url, headers, HTTPClient.Method.METHOD_GET)
	if error != OK:
		http.queue_free()
		return false
		
	var result = await http.request_completed
	var response_code = result[1]
	var body = result[3].get_string_from_utf8()
	
	http.queue_free()
	
	if response_code == 200:
		var parsed = JSON.parse_string(body)
		if parsed and (parsed.has("models") or parsed.has("data")):
			# LM Studio returns models in a "models" or "data" array
			return true
	
	return false


## Register a tool instance to be used in AI requests.
func register_tool(tool: RefCounted) -> void:
	if tool:
		tool.context_node = _parent
		_active_tools[tool.name] = tool


## Activates a skill, injecting its tools and returning its instructions.
func activate_skill(skill_id: String) -> String:
	if _activated_skill_ids.has(skill_id):
		return "Skill '%s' is already active." % skill_id
		
	var sm = load("res://addons/ai_assistant/skills/skill_manager.gd")
	var skill = sm.get_skill(skill_id)
	if not skill:
		return "Error: Skill '%s' not found." % skill_id
		
	# Register tools
	for script_path in skill.tool_scripts:
		var script = load(script_path)
		if script:
			var tool = script.new()
			# We check if it has the required methods instead of using 'is AITool' 
			# which might fail if AITool class is not globally registered.
			if tool.has_method("get_definition") and tool.has_method("execute"):
				register_tool(tool)
	
	_activated_skill_ids.append(skill_id)
	return "<activated_skill name=\"%s\">\n%s\n</activated_skill>" % [skill_id, skill.instructions]


func _execute_tool(tool_call: Dictionary) -> String:
	var function_name = tool_call.function.name
	var arguments = JSON.parse_string(tool_call.function.arguments)
	if arguments == null:
		arguments = {}
		
	# Check dynamically registered tools first
	if _active_tools.has(function_name):
		var tool = _active_tools[function_name]
		print("AI calling dynamic tool: ", function_name, " with args: ", arguments)
		return await tool.execute(arguments)
		
	# Fallback/Built-in tools
	var tool: RefCounted = null
	match function_name:
		"explore_godot_docs":
			tool = load("res://addons/ai_assistant/tools/godot_docs_tool.gd").new()
		"explore_project_resources":
			tool = load("res://addons/ai_assistant/tools/project_resources_tool.gd").new()
		"modify_project_resource":
			tool = load("res://addons/ai_assistant/tools/modify_project_resource_tool.gd").new()
		"validate_project_resource":
			tool = load("res://addons/ai_assistant/tools/validate_project_resource_tool.gd").new()
		"execute_script":
			tool = load("res://addons/ai_assistant/tools/execute_script_tool.gd").new()
		"capture_editor_view":
			tool = load("res://addons/ai_assistant/tools/capture_editor_view_tool.gd").new()
		"activate_skill":
			# Special handling for activate_skill which is built-in but stateful
			return activate_skill(arguments.get("name", ""))
	
	if tool:
		tool.context_node = _parent
		print("AI calling tool: ", function_name, " with args: ", arguments)
		return await tool.execute(arguments)
	
	return "Error: Tool " + function_name + " not found."


## Interrupt the ongoing AI request.
func cancel() -> void:
	if is_instance_valid(_active_client):
		_cancelled = true
		_active_client.cancel()


## Returns true if a request is currently active.
func is_busy() -> bool:
	return is_instance_valid(_active_client)


## Returns true if the last request was cancelled.
func was_cancelled() -> bool:
	return _cancelled


## Programmatically load a model if the backend is LM Studio.
func load_model(model_id: String) -> Error:
	var endpoint_to_use = api_endpoint if not api_endpoint.is_empty() else AISettings.get_string(AISettings.CONN, "base_url")
	if await _is_lm_studio(endpoint_to_use):
		var client = load("res://addons/ai_assistant/ai_client/lm_studio_client.gd").new()
		client.set_endpoint(endpoint_to_use)
		var key_to_use = api_key if not api_key.is_empty() else AISettings.get_string(AISettings.CONN, "api_key")
		client.set_api_key(key_to_use)
		_parent.add_child(client)
		
		var err = await client.load_model(model_id)
		if err != OK:
			print("AIRequestHandler: First load attempt failed for '%s'. Unloading all models and retrying..." % model_id)
			await client.unload_all_models()
			err = await client.load_model(model_id)
			if err != OK:
				print("AIRequestHandler: Second load attempt also failed for '%s'. Giving up." % model_id)
		
		client.queue_free()
		return err
	return OK


## Programmatically unload a model if the backend is LM Studio.
func unload_model(model_id: String) -> Error:
	var endpoint_to_use = api_endpoint if not api_endpoint.is_empty() else AISettings.get_string(AISettings.CONN, "base_url")
	if await _is_lm_studio(endpoint_to_use):
		var client = load("res://addons/ai_assistant/ai_client/lm_studio_client.gd").new()
		client.set_endpoint(endpoint_to_use)
		var key_to_use = api_key if not api_key.is_empty() else AISettings.get_string(AISettings.CONN, "api_key")
		client.set_api_key(key_to_use)
		_parent.add_child(client)
		var err = await client.unload_model(model_id)
		client.queue_free()
		return err
	return OK


## Check if a model supports vision capabilities.
func supports_vision(model_id: String) -> bool:
	if mock_client:
		return mock_client.supports_vision(model_id)
		
	var endpoint_to_use = api_endpoint if not api_endpoint.is_empty() else AISettings.get_string(AISettings.CONN, "base_url")
	var is_lms = await _is_lm_studio(endpoint_to_use)
	
	if is_lms:
		var client = load("res://addons/ai_assistant/ai_client/lm_studio_client.gd").new()
		client.set_endpoint(endpoint_to_use)
		var key_to_use = api_key if not api_key.is_empty() else AISettings.get_string(AISettings.CONN, "api_key")
		client.set_api_key(key_to_use)
		_parent.add_child(client)
		var result = await client.supports_vision(model_id)
		client.queue_free()
		return result
		
	return true # Default for non-LM Studio
