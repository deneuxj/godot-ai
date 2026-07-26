## AIChatPanel - Editor dock UI controller for the AIChat node.
##
## Connects to the currently selected AIChat node in the editor,
## provides a chat interface to interact with the AI while maintaining
## conversational context.

@tool
# REQ-EDITOR-0002, REQ-EDITOR-0004: Unified view and state persistence
extends "res://addons/ai_assistant/ai_base_panel.gd"


var _current_node: AIChat = null

# UI node references
@onready var _history_display: VBoxContainer = find_child("HistoryDisplay")
@onready var _input_text_edit: TextEdit = find_child("InputTextEdit")
@onready var _send_button: Button = find_child("SendButton")
@onready var _cancel_button: Button = find_child("CancelButton")
@onready var _clear_button: Button = find_child("ClearButton")
@onready var _attach_button: Button = find_child("AttachButton")
@onready var _attachments_container: HBoxContainer = find_child("AttachmentsContainer")
@onready var _attachment_dialog: EditorFileDialog = find_child("AttachmentDialog")
@onready var _status_label: Label = find_child("StatusLabel")
@onready var _context_label: Label = find_child("ContextLabel")
@onready var _todo_label: Label = find_child("TodoLabel")
@onready var _progress_bar: ProgressBar = find_child("ProgressBar")
@onready var _unload_button: Button = find_child("UnloadButton")
@onready var _compress_button: Button = find_child("CompressButton")
@onready var _copy_context_button: Button = find_child("CopyContextButton")
@onready var _aggressive_check: CheckButton = find_child("AggressiveCompression")


var _pending_attachments: Array[String] = []
var _last_prompt: String = ""
var _last_attachments: Array[String] = []


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
	if _unload_button:
		_unload_button.pressed.connect(_on_unload_pressed)
	if _compress_button:
		_compress_button.pressed.connect(_on_compress_pressed)
	if _copy_context_button:
		_copy_context_button.pressed.connect(_on_copy_context_pressed)
	if _aggressive_check:
		_aggressive_check.toggled.connect(_on_aggressive_toggled)
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
		if _current_node.is_connected("chat_cancelled", _on_chat_cancelled):
			_current_node.disconnect("chat_cancelled", _on_chat_cancelled)
		if _current_node.is_connected("chat_error", _on_chat_error):
			_current_node.disconnect("chat_error", _on_chat_error)
		if _current_node.is_connected("status_updated", _on_status_updated):
			_current_node.disconnect("status_updated", _on_status_updated)
		if _current_node.is_connected("context_length_updated", _on_context_length_updated):
			_current_node.disconnect("context_length_updated", _on_context_length_updated)
		if _current_node.is_connected("todo_list_updated", _on_todo_list_updated):
			_current_node.disconnect("todo_list_updated", _on_todo_list_updated)
		if _current_node.is_connected("history_changed", _on_history_changed):
			_current_node.disconnect("history_changed", _on_history_changed)


func _update_for_node(node: Node) -> void:
	_disconnect_from_node()

	_current_node = null

	if node is AIChat:
		_current_node = node as AIChat
		_current_node.editor_interface = _editor_interface

		# Connect signals from the node.
		_current_node.connect("chat_started", _on_chat_started)
		_current_node.connect("progress", _on_node_progress)
		_current_node.connect("chat_finished", _on_chat_finished)
		_current_node.connect("chat_cancelled", _on_chat_cancelled)
		_current_node.connect("chat_error", _on_chat_error)
		_current_node.connect("status_updated", _on_status_updated)
		_current_node.connect("context_length_updated", _on_context_length_updated)
		_current_node.connect("todo_list_updated", _on_todo_list_updated)
		_current_node.connect("history_changed", _on_history_changed)

		# Refresh UI state.
		_update_display()
		_aggressive_check.button_pressed = _current_node.aggressive_compression
		var busy = _current_node.is_busy()
		_status_label.text = "Status: Typing..." if busy else "Status: Ready"
		_send_button.disabled = busy
		_cancel_button.disabled = not busy
		_update_status_theme()
		
		# Initial context update
		var len = _current_node.get_context_length()
		_on_context_length_updated(len.tokens, len.characters)
		_on_todo_list_updated(_current_node.todo_list)
	else:
		for child in _history_display.get_children():
			child.queue_free()
		_status_label.text = "No AIChat selected"
		_context_label.text = ""
		_todo_label.text = ""
		_progress_bar.value = 0.0
		_status_label.remove_theme_color_override("font_color")


# --- Send / Cancel / Clear ---

func _on_visibility_changed() -> void:
	if visible and is_instance_valid(_current_node):
		_update_display()

func _format_thinking(text: String) -> String:
	var formatted = text.replace("<think>", "[color=gray][i]")
	formatted = formatted.replace("</think>", "[/i][/color]")
	# If there's an open <think> without a closing tag (e.g. during streaming)
	if formatted.count("[color=gray][i]") > formatted.count("[/i][/color]"):
		formatted += "[/i][/color]"
	return formatted

func _on_send_pressed() -> void:
	if is_instance_valid(_current_node):
		var prompt := _input_text_edit.text.strip_edges()
		if prompt.is_empty() and _pending_attachments.is_empty():
			return
		
		# Store for potential retry on error
		_last_prompt = prompt
		_last_attachments = _pending_attachments.duplicate()
		
		_input_text_edit.text = ""
		_send_button.disabled = true
		_cancel_button.disabled = false
		_current_node.send_message(prompt, _pending_attachments)
		_pending_attachments.clear()
		_update_attachments_ui()
		_update_display()


func _on_cancel_pressed() -> void:
	if is_instance_valid(_current_node):
		_current_node.cancel()
		_status_label.text = "Status: Interrupting..."
		_update_status()


func _on_clear_pressed() -> void:
	if is_instance_valid(_current_node):
		_current_node.clear_history()
		_pending_attachments.clear()
		_update_attachments_ui()
		_update_display()


# REQ-EDITOR-0005: Attach project resources
func _on_attach_pressed() -> void:
	if _attachment_dialog:
		_attachment_dialog.popup_file_dialog()


func _on_unload_pressed() -> void:
	if is_instance_valid(_current_node):
		_current_node.unload_model()


func _on_compress_pressed() -> void:
	if is_instance_valid(_current_node):
		_current_node.compress_context(true)
		_update_display()


func _on_copy_context_pressed() -> void:
	if is_instance_valid(_current_node):
		var json = _current_node.get_last_context_json()
		DisplayServer.clipboard_set(json)
		_status_label.text = "Status: Context copied to clipboard"


func _on_aggressive_toggled(toggled: bool) -> void:
	if is_instance_valid(_current_node):
		_current_node.aggressive_compression = toggled


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

# REQ-EDITOR-0008: Granular status feedback
# REQ-TOOL-0005: Tool execution transparent to user (and status updates)
func _on_chat_started() -> void:
	_update_status()


func _on_node_progress(_chunks: Array[String]) -> void:
	_update_display()


func _on_chat_finished(_response: String) -> void:
	_status_label.text = "Status: Finished"
	_progress_bar.value = 100.0
	
	# Successful response, clear retry state
	_last_prompt = ""
	_last_attachments.clear()
	
	_update_display()
	_update_status()


# REQ-EDITOR-0009: Interrupt/Cancel
func _on_chat_cancelled() -> void:
	_status_label.text = "Status: Cancelled"
	_update_display()
	_update_status()


# REQ-EDITOR-0006: Restore prompt on error
func _on_chat_error(err: String) -> void:
	_status_label.text = "Status: Error - " + err
	
	# Restore last message on error
	if not _last_prompt.is_empty() or not _last_attachments.is_empty():
		_input_text_edit.text = _last_prompt
		_pending_attachments = _last_attachments.duplicate()
		_update_attachments_ui()
	
	_update_status()


func _on_status_updated(status: String) -> void:
	_status_label.text = "Status: " + status
	_update_status()


# REQ-EDITOR-0007: Display context length
func _on_context_length_updated(tokens: int, chars: int) -> void:
	_context_label.text = "Context: %d tokens (%d chars)" % [tokens, chars]


# REQ-EDITOR-0010: Display TODO list status
func _on_todo_list_updated(list: Array[Dictionary]) -> void:
	if list.is_empty():
		_todo_label.text = ""
		_todo_label.tooltip_text = ""
		return
	
	var done_count = 0
	var current_idx = list.size()
	for i in range(list.size()):
		if list[i].done:
			done_count += 1
		elif current_idx == list.size():
			current_idx = i
	
	var progress_text = " (%d/%d)" % [done_count, list.size()]
	
	var completed_to_show = 1 if current_idx > 0 else 0
	var non_completed_available = list.size() - current_idx
	var non_completed_to_show = min(non_completed_available, 5 - completed_to_show)
	
	var extra_slots = 5 - (completed_to_show + non_completed_to_show)
	if extra_slots > 0 and current_idx > completed_to_show:
		completed_to_show += min(current_idx - completed_to_show, extra_slots)
		
	var start_idx = current_idx - completed_to_show
	var end_idx = current_idx + non_completed_to_show
	
	var display_lines = PackedStringArray()
	for i in range(start_idx, end_idx):
		var task = list[i]
		if task.done:
			display_lines.append("✓ " + task.text)
		elif i == current_idx:
			display_lines.append("> " + task.text)
		else:
			display_lines.append("  " + task.text)
			
	_todo_label.text = "TODO%s:\n%s" % [progress_text, "\n".join(display_lines)]
	
	var current_task_text = "All tasks completed!"
	if current_idx < list.size():
		current_task_text = list[current_idx].text
	_todo_label.tooltip_text = "Current Task: " + current_task_text


func _on_history_changed(scroll_to_bottom: bool = true) -> void:
	_update_display(scroll_to_bottom)


# --- Status Binding ---

func _update_status() -> void:
	if not is_instance_valid(_current_node):
		return

	var status = _current_node.chat_status
	var busy = (status == AIChat.ChatStatus.BUSY)
	
	_send_button.disabled = busy
	_cancel_button.disabled = not busy
	
	match status:
		AIChat.ChatStatus.IDLE:
			if _status_label.text == "Status: Typing..." or _status_label.text.is_empty():
				_status_label.text = "Status: Ready"
		AIChat.ChatStatus.BUSY:
			if _status_label.text.is_empty() or _status_label.text == "Status: Ready":
				_status_label.text = "Status: Typing..."
		AIChat.ChatStatus.CANCELLED:
			_status_label.text = "Status: Cancelled"
		AIChat.ChatStatus.ERROR:
			# Keep existing error text if it was set by _on_chat_error
			if not _status_label.text.contains("Error"):
				_status_label.text = "Status: Error"

	_update_status_theme()


# --- Display ---

func _get_or_create_msg_container(index: int) -> VBoxContainer:
	if index < _history_display.get_child_count():
		var child = _history_display.get_child(index)
		child.show()
		return child as VBoxContainer
	
	var msg_container = VBoxContainer.new()
	msg_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var header_row = HBoxContainer.new()
	msg_container.add_child(header_row)
	
	var role_label = Label.new()
	role_label.name = "RoleLabel"
	role_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(role_label)
	
	var del_btn = Button.new()
	del_btn.name = "DelBtn"
	del_btn.text = "X"
	del_btn.tooltip_text = "Delete this message"
	del_btn.pressed.connect(func(): if is_instance_valid(_current_node): _current_node.delete_message(del_btn.get_meta("idx")))
	header_row.add_child(del_btn)
	
	var del_from_btn = Button.new()
	del_from_btn.name = "DelFromBtn"
	del_from_btn.text = "X↓"
	del_from_btn.tooltip_text = "Delete this message and all following messages"
	del_from_btn.pressed.connect(func(): if is_instance_valid(_current_node): _current_node.delete_messages_from(del_from_btn.get_meta("idx")))
	header_row.add_child(del_from_btn)
	
	var text_display = RichTextLabel.new()
	text_display.name = "TextDisplay"
	text_display.bbcode_enabled = true
	text_display.fit_content = true
	text_display.selection_enabled = true
	text_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_container.add_child(text_display)
	
	var sep = HSeparator.new()
	msg_container.add_child(sep)
	
	_history_display.add_child(msg_container)
	return msg_container

func _update_display(scroll_to_bottom: bool = true) -> void:
	if not is_instance_valid(_current_node):
		return

	var i := 0
	for msg in _current_node.chat_history:
		var msg_container = _get_or_create_msg_container(i)
		
		var header_row = msg_container.get_child(0)
		var role_label = header_row.get_node("RoleLabel") as Label
		var del_btn = header_row.get_node("DelBtn") as Button
		var del_from_btn = header_row.get_node("DelFromBtn") as Button
		var text_display = msg_container.get_node("TextDisplay") as RichTextLabel
		
		del_btn.set_meta("idx", i)
		del_from_btn.set_meta("idx", i)
		
		del_btn.show()
		del_from_btn.show()
		
		var role: String = msg.role.capitalize()
		var color: String = "#4285f4" if msg.role == "user" else "#34a853"
		if msg.role == "tool":
			color = "#fbbc05"
		role_label.text = "[%s]" % role
		role_label.add_theme_color_override("font_color", Color(color))
		
		var msg_text := ""
		if msg.has("tool_calls"):
			msg_text += "[i]"
			for tool_call in msg.tool_calls:
				var fn = tool_call.function.name
				var args = tool_call.function.arguments
				msg_text += "(Calling tool: %s with args: %s)\n" % [fn, args]
			msg_text += "[/i]"
		
		if msg.role == "tool":
			var content: String = msg.get("content", "")
			if content.length() > 100:
				content = content.left(100) + "..."
			msg_text += content
		elif msg.get("content") is String:
			msg_text += _format_thinking(msg.get("content"))
		elif msg.get("content") is Array:
			var text_content := ""
			var images := 0
			var content_array = msg.get("content")
			for part in content_array:
				if part.get("type") == "text":
					text_content += part.get("text", "")
				elif part.get("type") == "image_url":
					images += 1
			msg_text += text_content
			if images > 0:
				msg_text += "[i] (%d image attachment%s)[/i]" % [images, "s" if images > 1 else ""]
		
		if text_display.text != msg_text:
			text_display.text = msg_text
		
		i += 1
	
	# Show partial response if currently typing.
	if not _current_node.partial_response.is_empty():
		var msg_container = _get_or_create_msg_container(i)
		
		var header_row = msg_container.get_child(0)
		var role_label = header_row.get_node("RoleLabel") as Label
		var del_btn = header_row.get_node("DelBtn") as Button
		var del_from_btn = header_row.get_node("DelFromBtn") as Button
		var text_display = msg_container.get_node("TextDisplay") as RichTextLabel
		
		del_btn.hide()
		del_from_btn.hide()
		
		role_label.text = "[Assistant]"
		role_label.add_theme_color_override("font_color", Color("#34a853"))
		
		var formatted_partial = _format_thinking(_current_node.partial_response)
		if text_display.text != formatted_partial:
			text_display.text = formatted_partial
			
		i += 1
		
	# Hide unused containers
	while i < _history_display.get_child_count():
		_history_display.get_child(i).hide()
		i += 1
		
	if scroll_to_bottom:
		call_deferred("_scroll_to_bottom")

func _scroll_to_bottom() -> void:
	var scroll_container := _history_display.get_parent() as ScrollContainer
	if scroll_container:
		# Wait a frame to allow the VBoxContainer to recalculate its height
		await get_tree().process_frame
		var scroll := scroll_container.get_v_scroll_bar()
		scroll.value = scroll.max_value

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
