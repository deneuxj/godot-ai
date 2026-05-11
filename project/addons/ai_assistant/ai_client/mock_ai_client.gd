## MockAIClient - A mock implementation of AIClient for testing.
##
## Allows pre-configuring responses (text or tool calls) for testing
## the AI Assistant without a real LLM backend.

class_name MockAIClient
extends AIClient

## Array of pre-configured responses to return sequentially.
## Each entry can be a String (text response) or a Dictionary (e.g. tool calls).
var response_queue: Array = []

## Delay in milliseconds before returning a response (simulates network latency).
var response_delay_ms: int = 100

var _is_cancelled: bool = false


func chat(messages: Array[Dictionary], tools: Array[Dictionary] = []) -> Variant:
	if response_delay_ms > 0:
		await get_tree().create_timer(response_delay_ms / 1000.0).timeout
	
	if _is_cancelled:
		return ""

	if response_queue.is_empty():
		return "Error: Mock AI: No response configured in queue."
	
	return response_queue.pop_front()


func chat_stream(messages: Array[Dictionary], tools: Array[Dictionary] = []) -> Variant:
	if response_delay_ms > 0:
		await get_tree().create_timer(response_delay_ms / 1000.0).timeout
	
	if _is_cancelled:
		return ""

	if response_queue.is_empty():
		var msg = "Error: Mock AI: No response configured in queue."
		var chunks: Array[String] = [msg]
		progress.emit(chunks)
		return msg
	
	var response = response_queue.pop_front()
	
	if response is String:
		# Simulate streaming by splitting into chunks
		var words = response.split(" ", false)
		for i in range(words.size()):
			if _is_cancelled: break
			var chunk = words[i] + (" " if i < words.size() - 1 else "")
			var chunks: Array[String] = [chunk]
			progress.emit(chunks)
			await get_tree().create_timer(0.01).timeout # Small chunk delay
		return response
	
	return response


func cancel() -> void:
	_is_cancelled = true


func supports_vision(_model_id: String) -> bool:
	return true
