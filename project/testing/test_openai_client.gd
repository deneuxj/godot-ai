## Test scene controller for OpenAIClient manual testing.
##
## Attach to the root Node2D of test_openai_client.tscn.
## Configure endpoint, API key, and model in the inspector,
## then press the buttons to test non-streaming and streaming chat.

@tool
extends Node2D


## API endpoint URL.
@export var api_endpoint: String = "http://localhost:1234"

## API key (leave empty for servers that don't require auth).
@export var api_key: String = ""

## Model name to use.
@export var model_name: String = "local-model"

## Maximum tokens in the response.
@export var max_tokens: int = 4096

## The user message to send.
@export var user_message: String = "Hello, what can you do?"


## Internal UI references.
@onready var _status_label: Label = $UI/MainVBox/StatusRow/StatusLabel
@onready var _progress_bar: ProgressBar = $UI/MainVBox/StatusRow/ProgressBar
@onready var _response_text_edit: TextEdit = $UI/MainVBox/OutputContainer/ResponseVBox/Response
@onready var _streaming_text_edit: TextEdit = $UI/MainVBox/OutputContainer/StreamingVBox/StreamingResponse
@onready var _endpoint_line: LineEdit = $UI/MainVBox/ConfigVBox/EndpointRow/Endpoint
@onready var _api_key_line: LineEdit = $UI/MainVBox/ConfigVBox/ApiKeyRow/ApiKey
@onready var _model_line: LineEdit = $UI/MainVBox/ConfigVBox/ModelRow/Model
@onready var _max_tokens_spin: SpinBox = $UI/MainVBox/ConfigVBox/MaxTokensRow/MaxTokens
@onready var _user_message_line: LineEdit = $UI/MainVBox/ConfigVBox/UserMessageRow/UserMessage


func _ready() -> void:
	_response_text_edit.placeholder_text = "Response will appear here..."
	_streaming_text_edit.placeholder_text = "Streaming output will appear here..."
	_status_label.text = "Status: Ready"
	_progress_bar.value = 0.0

	# Sync inspector values into the UI fields.
	_endpoint_line.text = api_endpoint
	_api_key_line.text = api_key
	_model_line.text = model_name
	_max_tokens_spin.value = max_tokens
	_user_message_line.text = user_message

	# Connect button signals.
	$UI/MainVBox/ConfigVBox/ButtonsRow/TestChatBtn.pressed.connect(_on_test_chat_pressed)
	$UI/MainVBox/ConfigVBox/ButtonsRow/TestStreamBtn.pressed.connect(_on_test_stream_pressed)

	# Sync UI changes back to inspector-exposed vars.
	_endpoint_line.text_changed.connect(_on_endpoint_changed)
	_api_key_line.text_changed.connect(_on_api_key_changed)
	_model_line.text_changed.connect(_on_model_changed)
	_max_tokens_spin.value_changed.connect(_on_max_tokens_changed)
	_user_message_line.text_changed.connect(_on_user_message_changed)


func _on_endpoint_changed(value: String) -> void:
	api_endpoint = value


func _on_api_key_changed(value: String) -> void:
	api_key = value


func _on_model_changed(value: String) -> void:
	model_name = value


func _on_max_tokens_changed(value: float) -> void:
	max_tokens = int(value)


func _on_user_message_changed(value: String) -> void:
	user_message = value


## Build a messages array with a system prompt and user message.
func _build_messages(prompt: String) -> Array[Dictionary]:
	return [
		{
			"role": "system",
			"content": "You are a helpful assistant. Keep responses concise.",
		},
		{"role": "user", "content": prompt},
	]


## Test the non-streaming chat API.
func _on_test_chat_pressed() -> void:
	var endpoint: String = _endpoint_line.text.strip_edges()
	if endpoint.is_empty():
		_status_label.text = "Status: Error — endpoint is empty"
		return

	_status_label.text = "Status: Sending non-streaming request..."
	_progress_bar.value = 0.0
	_response_text_edit.text = ""

	var client := OpenAIClient.new()
	client.set_endpoint(endpoint)
	var key: String = _api_key_line.text.strip_edges()
	if key != "":
		client.set_api_key(key)
	client.set_model(_model_line.text.strip_edges())
	client.set_max_tokens(int(_max_tokens_spin.value))

	add_child(client)

	var messages := _build_messages(_user_message_line.text.strip_edges())
	var response: Variant = await client.chat(messages)

	if typeof(response) == TYPE_STRING and response.is_empty():
		_status_label.text = "Status: Request failed or returned empty"
	elif typeof(response) == TYPE_DICTIONARY:
		_status_label.text = "Status: Received tool calls (not handled in this test)"
		response = JSON.stringify(response, "  ")
	else:
		_status_label.text = "Status: Non-streaming response received"

	_response_text_edit.text = str(response)
	_progress_bar.value = 100.0

	client.queue_free()


## Test the streaming chat API.
func _on_test_stream_pressed() -> void:
	var endpoint: String = _endpoint_line.text.strip_edges()
	if endpoint.is_empty():
		_status_label.text = "Status: Error — endpoint is empty"
		return

	_status_label.text = "Status: Sending streaming request..."
	_progress_bar.value = 0.0
	_streaming_text_edit.text = ""

	var client := OpenAIClient.new()
	client.set_endpoint(endpoint)
	var key: String = _api_key_line.text.strip_edges()
	if key != "":
		client.set_api_key(key)
	client.set_model(_model_line.text.strip_edges())
	client.set_max_tokens(int(_max_tokens_spin.value))

	add_child(client)

	var messages := _build_messages(_user_message_line.text.strip_edges())

	# Connect the progress signal before calling chat_stream.
	client.progress.connect(_on_stream_progress)

	var full_response: Variant = await client.chat_stream(messages)

	if typeof(full_response) == TYPE_STRING and full_response.is_empty():
		_status_label.text = "Status: Request failed or returned empty"
	elif typeof(full_response) == TYPE_DICTIONARY:
		_status_label.text = "Status: Received tool calls (not handled in this test)"
		full_response = JSON.stringify(full_response, "  ")
	else:
		_status_label.text = "Status: Streaming response received"

	_streaming_text_edit.text = str(full_response)
	_progress_bar.value = 100.0

	client.queue_free()


## Emitted by the client for each streaming chunk.
func _on_stream_progress(chunks: Array[String]) -> void:
	for chunk in chunks:
		_streaming_text_edit.text += chunk
		_progress_bar.value += (100.0 / max(chunks.size(), 1))
