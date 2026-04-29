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


## Non-streaming chat: sends [param messages] and returns the full response.
##
## Uses [HTTPRequest] to POST to the configured endpoint's `/v1/chat/completions`
## path. Waits for the request to complete, then parses the JSON response
## to extract `choices[0].message.content`.
##
## Returns an empty string on failure.
func chat(messages: Array[Dictionary]) -> String:
	_ensure_http_request()
	var body: Dictionary = {
		"model": model,
		"messages": messages,
		"max_tokens": max_tokens,
	}

	var headers: PackedStringArray = ["Content-Type: application/json"]
	if api_key != "":
		headers.append("Authorization: Bearer " + api_key)

	var error_code: int = _http_request.request(
		endpoint + "/v1/chat/completions",
		headers,
		HTTPClient.Method.METHOD_POST,
		JSON.stringify(body),
	)

	if error_code != OK:
		push_error("HTTP request failed: %d" % error_code)
		return ""

	# Wait for the request to complete.
	# request_completed(result: int, status_code: int, headers: PackedStringArray, body: PackedByteArray)
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

	# Parse JSON response body.
	var parsed: Variant = JSON.parse_string(response_body)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Failed to parse JSON response")
		return ""

	var response_body_dict: Dictionary = parsed as Dictionary

	# Extract the first choice's message content.
	var choices: Array = response_body_dict.get("choices", [])
	if choices.is_empty():
		push_error("Empty choices in API response")
		return ""

	var content: String = (choices[0] as Dictionary).get("message", {}).get("content", "")
	return content


## Streaming chat: sends [param messages] and emits [signal progress] per chunk.
##
## Parses Server-Sent Events (SSE) format from the response body. Each chunk
## contains a JSON object with `choices[0].delta.content`. The signal is
## emitted for each chunk as it arrives.
##
## Returns the full concatenated response string when streaming finishes.
func chat_stream(messages: Array[Dictionary]) -> String:
	_ensure_http_request()
	var body: Dictionary = {
		"model": model,
		"messages": messages,
		"max_tokens": max_tokens,
		"stream": true,
	}

	var headers: PackedStringArray = ["Content-Type: application/json"]
	if api_key != "":
		headers.append("Authorization: Bearer " + api_key)

	var error_code: int = _http_request.request(
		endpoint + "/v1/chat/completions",
		headers,
		HTTPClient.Method.METHOD_POST,
		JSON.stringify(body),
	)

	if error_code != OK:
		push_error("HTTP request failed: %d" % error_code)
		return ""

	# Wait for the request to complete.
	# request_completed(result: int, status_code: int, headers: PackedStringArray, body: PackedByteArray)
	var result: Array = await _http_request.request_completed
	var http_error: int = result[0]
	var response_code: int = result[1]
	var response_body: String = result[3].get_string_from_utf8()

	if http_error != OK:
		push_error("HTTP request failed: %d" % http_error)
		return ""

	if response_code != 200:
		push_error("API error: HTTP %d" % response_code)
		return ""

	# Parse SSE stream: each line starting with "data: " contains JSON.
	var chunks: PackedStringArray = []
	var full_content: String = ""
	var lines: PackedStringArray = response_body.split("\n")

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
		var chunk_content: String = delta.get("content", "")
		if chunk_content != "":
			chunks.append(chunk_content)
			full_content += chunk_content

	# Emit progress signal with all collected chunks.
	if chunks.size() > 0:
		progress.emit(chunks)

	return full_content
