## OpenAIClient - OpenAI-compatible API implementation.
##
## Works with LM Studio, Ollama, OpenAI, and any compatible server.

class_name OpenAIClient
extends AIClient


signal progress(chunks: Array[String])


func chat(messages: Array[Dictionary]) -> String:
	var body = {
		"model": model,
		"messages": messages,
		"max_tokens": max_tokens,
	}

	var headers = ["Content-Type: application/json"]
	if api_key != "":
		headers.append("Authorization: Bearer " + api_key)

	var http_request = HTTPRequest.new()

	var error = http_request.request(
		endpoint + "/v1/chat/completions",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)

	if error != OK:
		http_request.queue_free()
		push_error("HTTP request failed: %d" % error)
		return ""

	var response = await http_request.request_completed
	http_request.queue_free()

	var result = JSON.parse_string(response[3])
	if result == null or "choices" not in result or result["choices"].size() == 0:
		push_error("Invalid AI response")
		return ""

	return result["choices"][0]["message"]["content"]


func chat_stream(messages: Array[Dictionary]) -> Signal:
	var body = {
		"model": model,
		"messages": messages,
		"max_tokens": max_tokens,
		"stream": true,
	}

	var headers = ["Content-Type: application/json"]
	if api_key != "":
		headers.append("Authorization: Bearer " + api_key)

	var http_request = HTTPRequest.new()

	var error = http_request.request(
		endpoint + "/v1/chat/completions",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)

	if error != OK:
		http_request.queue_free()
		push_error("HTTP request failed: %d" % error)
		return Signal()

	var response = await http_request.request_completed
	http_request.queue_free()

	var full_response = ""
	var chunks: Array[String] = []

	var stream_lines = response[3].get_string_from_utf8().split("\n")
	for line in stream_lines:
		if line.begins_with("data: "):
			var data = line.substr(6)
			if data == "[DONE]":
				break

			var parsed = JSON.parse_string(data)
			if parsed == null:
				continue

			if "choices" in parsed and parsed["choices"].size() > 0:
				var delta = parsed["choices"][0].get("delta", {})
				if "content" in delta and delta["content"] != null:
					var content = delta["content"]
					full_response += content
					chunks.append(content)

	if chunks.size() > 0:
		progress.emit(chunks)

	return progress
