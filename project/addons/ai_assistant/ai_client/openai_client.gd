## OpenAIClient - OpenAI-compatible API implementation.

class_name OpenAIClient
extends AIClient


signal progress(chunks: Array[String])


func chat(messages: Array[Dictionary]) -> String:
	return ""


func chat_stream(messages: Array[Dictionary]) -> Signal:
	return Signal()
