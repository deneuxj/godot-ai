## OpenAIClient - OpenAI-compatible API implementation.
##
## Works with any OpenAI-compatible server: LM Studio, Ollama, OpenAI, etc.
## Configured via [member AIClient.endpoint], [member AIClient.api_key],
## [member AIClient.model], and [member AIClient.max_tokens].

class_name OpenAIClient
extends AIClient


## Internal HTTPRequest node for making API calls.
var _http_request: HTTPRequest
var _http_request_ready: bool = false


func _ready() -> void:
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request_ready = true


func _exit_tree() -> void:
	if is_instance_valid(_http_request):
		_http_request.queue_free()
		_http_request_ready = false


func _ensure_http_request() -> void:
	if not _http_request_ready:
		_http_request = HTTPRequest.new()
		add_child(_http_request)
		_http_request_ready = true


## Interrupt the ongoing AI request.
func cancel() -> void:
	if is_instance_valid(_http_request):
		_http_request.cancel_request()


## Non-streaming chat: sends [param messages] and returns the full response.
## [param tools] is an optional array of tool definition dictionaries.
func chat(messages: Array[Dictionary], tools: Array[Dictionary] = []) -> Variant:
	_ensure_http_request()
	var body: Dictionary = {
		"model": model,
		"messages": messages,
		"max_tokens": max_tokens,
	}
	
	if not tools.is_empty():
		body["tools"] = tools

	var headers: PackedStringArray = ["Content-Type: application/json"]
	if api_key != "":
		headers.append("Authorization: Bearer " + api_key)

	var request_url = endpoint
	if not request_url.ends_with("/v1"):
		request_url += "/v1"
	request_url += "/chat/completions"

	var error_code: int = _http_request.request(
		request_url,
		headers,
		HTTPClient.Method.METHOD_POST,
		JSON.stringify(body),
	)

	if error_code != OK:
		push_error("HTTP request failed: %d" % error_code)
		return ""

	var result: Array = await _http_request.request_completed
	var error_code_param: int = result[0]
	var response_code: int = result[1]
	var response_body: String = result[3].get_string_from_utf8()

	if error_code_param != OK:
		push_error("HTTP request failed: %d" % error_code_param)
		return ""

	if response_code != 200:
		var err_json: Variant = JSON.parse_string(response_body)
		var err_msg: String = "Unknown error"
		if typeof(err_json) == TYPE_DICTIONARY:
			err_msg = (err_json as Dictionary).get("error", {}).get("message", "Unknown error") as String
		push_error("API error: HTTP %d — %s" % [response_code, err_msg])
		return ""

	var parsed: Variant = JSON.parse_string(response_body)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Failed to parse JSON response")
		return ""

	var response_body_dict: Dictionary = parsed as Dictionary

	var choices: Array = response_body_dict.get("choices", [])
	if choices.is_empty():
		push_error("Empty choices in API response")
		return ""

	var message = (choices[0] as Dictionary).get("message", {})
	
	if message.has("tool_calls"):
		return {"tool_calls": message["tool_calls"]}
		
	return message.get("content", "")


## Streaming chat: sends [param messages] and emits [signal progress] per chunk.
## [param tools] is an optional array of tool definition dictionaries.
func chat_stream(messages: Array[Dictionary], tools: Array[Dictionary] = []) -> Variant:
	_ensure_http_request()
	var body: Dictionary = {
		"model": model,
		"messages": messages,
		"max_tokens": max_tokens,
		"stream": true,
	}
	
	if not tools.is_empty():
		body["tools"] = tools

	var headers: PackedStringArray = ["Content-Type: application/json"]
	if api_key != "":
		headers.append("Authorization: Bearer " + api_key)

	var request_url = endpoint
	if not request_url.ends_with("/v1"):
		request_url += "/v1"
	request_url += "/chat/completions"

	print("[%s] OpenAIClient: Sending streaming request to %s" % [Time.get_time_string_from_system(), request_url])
	var error_code: int = _http_request.request(
		request_url,
		headers,
		HTTPClient.Method.METHOD_POST,
		JSON.stringify(body),
	)

	if error_code != OK:
		push_error("HTTP request failed: %d" % error_code)
		return ""

	var result: Array = await _http_request.request_completed
	print("[%s] OpenAIClient: Request completed (connection closed). Processing chunks..." % Time.get_time_string_from_system())
	
	var http_error: int = result[0]
	var response_code: int = result[1]
	var response_body: String = result[3].get_string_from_utf8()

	if http_error != OK:
		push_error("HTTP request failed: %d" % http_error)
		return ""

	if response_code != 200:
		push_error("API error: HTTP %d" % response_code)
		return ""

	var chunks: PackedStringArray = []
	var full_content: String = ""
	var tool_calls: Array = []
	
	var lines: PackedStringArray = response_body.split("\n")
	print("[%s] OpenAIClient: Found %d lines in response body." % [Time.get_time_string_from_system(), lines.size()])

	for line in lines:
		line = line.strip_edges()
		if not line.begins_with("data: "):
			continue

		var data: String = line.substr(6)
		if data.strip_edges() == "[DONE]":
			break

		var parsed: Variant = JSON.parse_string(data)
		if typeof(parsed) != TYPE_DICTIONARY:
			continue

		var choice: Dictionary = (parsed as Dictionary).get("choices", [{}])[0]
		var delta: Dictionary = choice.get("delta", {})
		
		# Handle tool calls in streaming
		if delta.has("tool_calls"):
			var delta_tool_calls = delta["tool_calls"]
			for tc in delta_tool_calls:
				var index = tc.get("index", 0)
				if tool_calls.size() <= index:
					tool_calls.append({
						"id": "",
						"type": "function",
						"function": {"name": "", "arguments": ""}
					})
				
				var target = tool_calls[index]
				if tc.has("id"): target["id"] += tc["id"]
				if tc.has("function"):
					if tc["function"].has("name"): target["function"]["name"] += tc["function"]["name"]
					if tc["function"].has("arguments"): target["function"]["arguments"] += tc["function"]["arguments"]

		var chunk_content: String = delta.get("content", "")
		if chunk_content != "":
			chunks.append(chunk_content)
			full_content += chunk_content
			# Emit chunks immediately if needed. We must use a typed array to match the signal.
			var typed_chunks: Array[String] = [chunk_content]
			progress.emit(typed_chunks)

	if not tool_calls.is_empty():
		return {"tool_calls": tool_calls}

	return full_content
