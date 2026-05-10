## AIClient - Abstract base class for AI chat clients.
##
## Subclass this to implement a different AI backend.
## Use `create_openai_client()` for the built-in OpenAI-compatible implementation.

class_name AIClient
extends Node

const AISettings = preload("res://addons/ai_assistant/settings/ai_settings.gd")


## Emitted when streaming chunks arrive during `chat_stream()`.
signal progress(chunks: Array[String])


## AI endpoint URL (e.g. "http://localhost:1234/v1").
@export
var endpoint: String = "http://localhost:1234/v1"

## API key for authentication.
@export
var api_key: String = ""

## Model name to use for completions.
@export
var model: String = "local-model"

## Maximum tokens in the response.
@export
var max_tokens: int = 4096


## Set the API endpoint URL.
## Returns self for method chaining.
func set_endpoint(url: String) -> AIClient:
	endpoint = url
	return self


## Set the API key for authentication.
## Returns self for method chaining.
func set_api_key(key: String) -> AIClient:
	api_key = key
	return self


## Set the model name for completions.
## Returns self for method chaining.
func set_model(model_name: String) -> AIClient:
	model = model_name
	return self


## Set the maximum number of tokens in the response.
## Returns self for method chaining.
func set_max_tokens(tokens: int) -> AIClient:
	max_tokens = tokens
	return self


## Send a chat request and return the full response as a string.
##
## Subclasses must override this method. The [param messages] parameter
## is an array of message dictionaries with "role" and "content" keys.
## [param tools] is an optional array of tool definition dictionaries.
func chat(messages: Array[Dictionary], tools: Array[Dictionary] = []) -> Variant:
	push_error("AIClient.chat() not implemented. Override in subclass.")
	return ""


## Send a streaming chat request.
##
## Subclasses must override this method. Chunks of the response are
## emitted via the [signal progress] signal as they arrive.
func chat_stream(messages: Array[Dictionary], tools: Array[Dictionary] = []) -> Variant:
	push_error("AIClient.chat_stream() not implemented. Override in subclass.")
	return ""


## Interrupt the ongoing AI request.
##
## Subclasses must override this method to stop the network request.
func cancel() -> void:
	push_error("AIClient.cancel() not implemented. Override in subclass.")


## Programmatically load a model (LM Studio specific).
func load_model(model_id: String) -> Error:
	return OK


## Programmatically unload a model (LM Studio specific).
func unload_model(model_id: String) -> Error:
	return OK


## Get a list of local models (LM Studio specific).
func get_local_models() -> Array:
	return []


## Check if a model supports vision capabilities.
func supports_vision(model_id: String) -> bool:
	return true


## Factory method that creates an [OpenAIClient] configured with project settings.
##
## Reads configuration from [member AISettings] defaults under the
## `ai/openai/` namespace. Call this from [class AIAgentAssisted3D] or
## the editor dock to get a ready-to-use client.
static func create_openai_client() -> OpenAIClient:
	var client := OpenAIClient.new()
	
	client.set_endpoint(AISettings.get_string(AISettings.CONN, "base_url"))
	
	var api_key: String = AISettings.get_string(AISettings.CONN, "api_key")
	if api_key != "":
		client.set_api_key(api_key)
	
	client.set_model(AISettings.get_string(AISettings.CONN, "model"))
	client.set_max_tokens(AISettings.get_int(AISettings.GEN, "max_tokens"))
	
	return client
