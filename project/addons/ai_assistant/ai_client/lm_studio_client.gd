## LMStudioClient - Native LM Studio API implementation.
##
## Extends OpenAIClient to add model management capabilities
## using LM Studio's native /api/v1/ endpoints.

class_name LMStudioClient
extends OpenAIClient

signal load_progress(percent: float)


## Load a model into memory.
func load_model(model_id: String) -> Error:
	_ensure_http_request()
	
	var url = endpoint + "/api/v1/models/load"
	var body = {"identifier": model_id}
	
	var headers: PackedStringArray = ["Content-Type: application/json"]
	if api_key != "":
		headers.append("Authorization: Bearer " + api_key)

	var error_code: int = _http_request.request(
		url,
		headers,
		HTTPClient.Method.METHOD_POST,
		JSON.stringify(body),
	)

	if error_code != OK:
		return error_code

	var result: Array = await _http_request.request_completed
	var response_code: int = result[1]
	
	if response_code == 200:
		return OK
	
	return ERR_CANT_CONNECT as Error


## Unload a model from memory.
func unload_model(model_id: String) -> Error:
	_ensure_http_request()
	
	var url = endpoint + "/api/v1/models/unload"
	var body = {"identifier": model_id}
	
	var headers: PackedStringArray = ["Content-Type: application/json"]
	if api_key != "":
		headers.append("Authorization: Bearer " + api_key)

	var error_code: int = _http_request.request(
		url,
		headers,
		HTTPClient.Method.METHOD_POST,
		JSON.stringify(body),
	)

	if error_code != OK:
		return error_code

	var result: Array = await _http_request.request_completed
	var response_code: int = result[1]
	
	if response_code == 200:
		return OK
	
	return ERR_CANT_CONNECT as Error


## List available local models.
func get_local_models() -> Array:
	_ensure_http_request()
	
	var url = endpoint + "/api/v1/models"
	
	var headers: PackedStringArray = ["Content-Type: application/json"]
	if api_key != "":
		headers.append("Authorization: Bearer " + api_key)

	var error_code: int = _http_request.request(
		url,
		headers,
		HTTPClient.Method.METHOD_GET
	)

	if error_code != OK:
		return []

	var result: Array = await _http_request.request_completed
	var response_code: int = result[1]
	var response_body: String = result[3].get_string_from_utf8()

	if response_code == 200:
		var parsed = JSON.parse_string(response_body)
		if parsed:
			if parsed.has("models"):
				return parsed["models"]
			elif parsed.has("data"):
				return parsed["data"]
	
	return []


## Check if a model supports vision capabilities.
func supports_vision(model_id: String) -> bool:
	var models = await get_local_models()
	for m in models:
		# Check both key and display_name as identifiers
		if m.get("key") == model_id or m.get("display_name") == model_id:
			var caps = m.get("capabilities", {})
			return caps.get("vision", false)
	return true # Fallback to true
