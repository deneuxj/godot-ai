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

## API endpoint URL override.
var api_endpoint: String = ""
## API key override.
var api_key: String = ""
## Model name override.
var model: String = ""


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
	var client := AIClient.create_openai_client()
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
	
	const MAX_TOOL_LOOPS = 5
	for i in range(MAX_TOOL_LOOPS):
		var result = await client.chat_stream(current_messages, tools)
		
		if _cancelled:
			break
			
		if typeof(result) == TYPE_DICTIONARY and result.has("tool_calls"):
			var tool_calls = result["tool_calls"]
			# Add the assistant message with tool calls to history
			current_messages.append({
				"role": "assistant",
				"tool_calls": tool_calls
			})
			
			# Execute each tool call
			for tool_call in tool_calls:
				var tool_result = _execute_tool(tool_call)
				current_messages.append({
					"role": "tool",
					"tool_call_id": tool_call.id,
					"name": tool_call.function.name,
					"content": tool_result
				})
			
			# Continue loop to send tool results back to AI
			continue
		else:
			final_response = str(result)
			break

	# 5. Cleanup.
	if is_instance_valid(client):
		client.queue_free()
	
	if _active_client == client:
		_active_client = null
	
	return final_response


func _execute_tool(tool_call: Dictionary) -> String:
	var function_name = tool_call.function.name
	var arguments = JSON.parse_string(tool_call.function.arguments)
	if arguments == null:
		arguments = {}
		
	var tool: AITool = null
	match function_name:
		"explore_godot_docs":
			tool = load("res://addons/ai_assistant/tools/godot_docs_tool.gd").new()
		"explore_project_resources":
			tool = load("res://addons/ai_assistant/tools/project_resources_tool.gd").new()
	
	if tool:
		print("AI calling tool: ", function_name, " with args: ", arguments)
		return tool.execute(arguments)
	
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
