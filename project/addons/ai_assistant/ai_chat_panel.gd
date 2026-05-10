## AIChatPanel - Editor dock UI controller for the AIChat node.
##
## Connects to the currently selected AIChat node in the editor,
## provides a chat interface to interact with the AI while maintaining
## conversational context.

@tool
extends "res://addons/ai_assistant/ai_base_panel.gd"


var _current_node: AIChat = null

# UI node references
@onready var _history_display: RichTextLabel = find_child("HistoryDisplay")
@onready var _input_text_edit: TextEdit = find_child("InputTextEdit")
@onready var _send_button: Button = find_child("SendButton")
@onready var _cancel_button: Button = find_child("CancelButton")
@onready var _clear_button: Button = find_child("ClearButton")
@onready var _attach_button: Button = find_child("AttachButton")
@onready var _attachments_container: HBoxContainer = find_child("AttachmentsContainer")
@onready var _attachment_dialog: EditorFileDialog = find_child("AttachmentDialog")
@onready var _status_label: Label = find_child("StatusLabel")
@onready var _progress_bar: ProgressBar = find_child("ProgressBar")


var _pending_attachments: Array[String] = []


func _on_ready() -> void:
	# Connect UI signals.
	if _send_button:
		_send_button.pressed.connect(_on_send_pressed)
	if _cancel_button:
		_cancel_button.pressed.connect(_on_cancel_pressed)
	if _clear_button:
		_clear_button.pressed.connect(_on_clear_pressed)
	if _attach_button:
		_attach_button.pressed.connect(_on_attach_pressed)
	if _attachment_dialog:
		_attachment_dialog.file_selected.connect(_on_file_selected)


func _on_exit_tree() -> void:
	_disconnect_from_node()


func _disconnect_from_node() -> void:
	if is_instance_valid(_current_node):
		if _current_node.is_connected("chat_started", _on_chat_started):
			_current_node.disconnect("chat_started", _on_chat_started)
		if _current_node.is_connected("progress", _on_node_progress):
			_current_node.disconnect("progress", _on_node_progress)
		if _current_node.is_connected("chat_finished", _on_chat_finished):
			_current_node.disconnect("chat_finished", _on_chat_finished)
		if _current_node.is_connected("chat_error", _on_chat_error):
			_current_node.disconnect("chat_error", _on_chat_error)


func _update_for_node(node: Node) -> void:
	_disconnect_from_node()

	_current_node = null

	if node is AIChat:
		_current_node = node as AIChat

		# Connect signals from the node.
		_current_node.connect("chat_started", _on_chat_started)
		_current_node.connect("progress", _on_node_progress)
		_current_node.connect("chat_finished", _on_chat_finished)
		_current_node.connect("chat_error", _on_chat_error)

		# Refresh UI state.
		_update_display()
		_status_label.text = "Status: Ready"
		_update_status_theme()
	else:
		_history_display.text = ""
		_status_label.text = "No AIChat selected"
		_progress_bar.value = 0.0
		_status_label.remove_theme_color_override("font_color")


# --- Send / Cancel / Clear ---

func _on_send_pressed() -> void:
	if is_instance_valid(_current_node):
		var prompt := _input_text_edit.text.strip_edges()
		if prompt.is_empty() and _pending_attachments.is_empty():
			return
		
		_input_text_edit.text = ""
		_current_node.send_message(prompt, _pending_attachments)
		_pending_attachments.clear()
		_update_attachments_ui()
		_update_display()


func _on_cancel_pressed() -> void:
	if is_instance_valid(_current_node):
		_current_node.cancel()
		_status_label.text = "Status: Cancelled"
		_send_button.disabled = false
		_cancel_button.disabled = true


func _on_clear_pressed() -> void:
	if is_instance_valid(_current_node):
		_current_node.clear_history()
		_pending_attachments.clear()
		_update_attachments_ui()
		_update_display()


func _on_attach_pressed() -> void:
	if _attachment_dialog:
		_attachment_dialog.popup_file_dialog()


func _on_file_selected(path: String) -> void:
	if not _pending_attachments.has(path):
		_pending_attachments.append(path)
		_update_attachments_ui()


func _update_attachments_ui() -> void:
	# Clear existing badges.
	for child in _attachments_container.get_children():
		child.queue_free()
	
	for path in _pending_attachments:
		var badge = Button.new()
		badge.text = path.get_file() + " [x]"
		badge.tooltip_text = path
		badge.flat = true
		badge.pressed.connect(func(): 
			_pending_attachments.erase(path)
			_update_attachments_ui()
		)
		_attachments_container.add_child(badge)


# --- Node Signals ---

func _on_chat_started() -> void:
	_status_label.text = "Status: Typing..."
	_send_button.disabled = true
	_cancel_button.disabled = false
	_update_status_theme()


func _on_node_progress(_chunks: Array[String]) -> void:
	_update_display()
	# Optional: Force scroll to bottom
	var scroll := _history_display.get_v_scroll_bar()
	scroll.value = scroll.max_value


func _on_chat_finished(_response: String) -> void:
	_status_label.text = "Status: Finished"
	_send_button.disabled = false
	_cancel_button.disabled = true
	_progress_bar.value = 100.0
	_update_display()
	_update_status_theme()


func _on_chat_error(err: String) -> void:
	_status_label.text = "Status: Error - " + err
	_send_button.disabled = false
	_cancel_button.disabled = true
	_update_status_theme()


# --- Display ---

func _update_display() -> void:
	if not is_instance_valid(_current_node):
		return

	_history_display.clear()
	
	for msg in _current_node.chat_history:
		var role: String = msg.role.capitalize()
		var color: String = "#4285f4" if msg.role == "user" else "#34a853"
		
		_history_display.push_color(Color(color))
		_history_display.append_text("[%s]: " % role)
		_history_display.pop()
		
		if msg.content is String:
			_history_display.append_text(msg.content + "\n\n")
		elif msg.content is Array:
			# Multi-modal content
			var text_content := ""
			var images := 0
			for part in msg.content:
				if part.get("type") == "text":
					text_content += part.get("text", "")
				elif part.get("type") == "image_url":
					images += 1
			
			_history_display.append_text(text_content)
			if images > 0:
				_history_display.push_italic()
				_history_display.append_text(" (%d image attachment%s)" % [images, "s" if images > 1 else ""])
				_history_display.pop()
			_history_display.append_text("\n\n")
	
	# Show partial response if currently typing.
	if not _current_node.partial_response.is_empty():
		_history_display.push_color(Color("#34a853"))
		_history_display.append_text("[Assistant]: ")
		_history_display.pop()
		_history_display.append_text(_current_node.partial_response)


func _update_status_theme() -> void:
	if not is_instance_valid(_current_node):
		return

	var color_key := "font_color"
	if _send_button.disabled:
		color_key = "typing"
	elif _status_label.text.contains("Error"):
		color_key = "error"
	elif _status_label.text.contains("Finished"):
		color_key = "success"
	
	_status_label.add_theme_color_override("font_color", _get_status_color(color_key))
