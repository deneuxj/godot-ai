## AIClient - Abstract base class for AI chat clients.

class_name AIClient


var endpoint: String = "http://localhost:1234/v1"
var api_key: String = ""
var model: String = "local-model"
var max_tokens: int = 4096


func chat(messages: Array[Dictionary]) -> String:
	return ""


func chat_stream(messages: Array[Dictionary]) -> Signal:
	return Signal()
