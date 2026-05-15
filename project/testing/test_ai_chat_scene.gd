## Test scene controller for AIChat.
##
## Connects a UI to an AIChat node to provide a simple chat interface.

extends Control


@onready var _chat_node: AIChat = $AIChat
@onready var _history_display: RichTextLabel = %HistoryDisplay
@onready var _input_field: LineEdit = %InputField
@onready var _send_button: Button = %SendButton
@onready var _clear_button: Button = %ClearButton
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	# Connect AIChat signals
	_chat_node.chat_started.connect(_on_chat_started)
	_chat_node.progress.connect(_on_chat_progress)
	_chat_node.chat_finished.connect(_on_chat_finished)
	_chat_node.chat_error.connect(_on_chat_error)
	
	# Connect UI signals
	_send_button.pressed.connect(_on_send_pressed)
	_input_field.text_submitted.connect(func(_text): _on_send_pressed())
	_clear_button.pressed.connect(_on_clear_pressed)
	
	_status_label.text = "Ready"
	_update_display()


func _on_send_pressed() -> void:
	var prompt := _input_field.text.strip_edges()
	if prompt.is_empty():
		return
	
	_input_field.clear()
	_chat_node.send_message(prompt)
	_update_display()


func _on_clear_pressed() -> void:
	_chat_node.clear_history()
	_update_display()
	_status_label.text = "History cleared"


func _on_chat_started() -> void:
	_status_label.text = "Typing..."
	_send_button.disabled = true


func _on_chat_progress(chunks: Array[String]) -> void:
	# We update the display on every chunk to show streaming.
	# For efficiency in a real app, you might just append the chunks to the last message.
	_update_display()
	# Optional: Force scroll to bottom
	var scroll := _history_display.get_v_scroll_bar()
	scroll.value = scroll.max_value


func _on_chat_finished(_response: String) -> void:
	_status_label.text = "Response received"
	_send_button.disabled = false
	_update_display()


func _on_chat_error(err: String) -> void:
	_status_label.text = "Error: " + err
	_send_button.disabled = false


func _update_display() -> void:
	_history_display.clear()
	
	for msg in _chat_node.chat_history:
		var role: String = msg.role.capitalize()
		var color: String = "#4285f4" if msg.role == "user" else "#34a853"
		
		_history_display.push_color(Color(color))
		_history_display.add_text("[%s]: " % role)
		_history_display.pop()
		
		_history_display.add_text(msg.get("content", "") + "\n\n")
	
	# Show partial response if currently typing.
	if not _chat_node.partial_response.is_empty():
		_history_display.push_color(Color("#34a853"))
		_history_display.add_text("[Assistant]: ")
		_history_display.pop()
		_history_display.add_text(_chat_node.partial_response)
