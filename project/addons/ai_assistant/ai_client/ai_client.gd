## AIClient - Abstract base class for AI chat clients.
##
## Subclass this to implement different AI backends
## (OpenAI-compatible, Anthropic, etc.).

class_name AIClient


var endpoint: String = "http://localhost:1234/v1"
var api_key: String = ""
var model: String = "local-model"
var max_tokens: int = 4096


## Non-streaming: returns full response as a string.
func chat(messages: Array[Dictionary]) -> String:
	push_error("Override in subclass: AIClient.chat()")
	return ""


## Streaming: yields chunks as they arrive via a signal.
func chat_stream(messages: Array[Dictionary]) -> Signal:
	push_error("Override in subclass: AIClient.chat_stream()")
	return Signal()


func set_endpoint(url: String) -> void:
	endpoint = url


func set_api_key(key: String) -> void:
	api_key = key


func set_model(model_name: String) -> void:
	model = model_name


func set_max_tokens(tokens: int) -> void:
	max_tokens = tokens
