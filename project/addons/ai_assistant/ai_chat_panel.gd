## AIChatPanel - Editor dock UI controller for the AIChat node.
##
## Connects to the currently selected AIChat node in the editor,
## provides a chat interface to interact with the AI while maintaining
## conversational context.

@tool
extends ScrollContainer


var _current_node: AIChat = null
var _editor_interface: EditorInterface

# UI node references
@onready var _history_display: RichTextLabel = find_child("HistoryDisplay")
@onready var _input_text_edit: TextEdit = find_child("InputTextEdit")
@onready var _send_button: Button = find_child("SendButton")
@onready var _cancel_button: Button = find_child("CancelButton")
@onready var _clear_button: Button = find_child("ClearButton")
@onready var _status_label: Label = find_child("StatusLabel")
@onready var _progress_bar: ProgressBar = find_child("ProgressBar")


# Called by the plugin after instantiation to inject the EditorInterface.
func _init_editor(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


func _ready() -> void:
	# Connect UI signals.
	if _send_button:
		_send_button.pressed.connect(_on_send_pressed)
	if _cancel_button:
		_cancel_button.pressed.connect(_on_cancel_pressed)
	if _clear_button:
		_clear_button.pressed.connect(_on_clear_pressed)

	# Connect to the editor's selection system.
	if is_instance_valid(_editor_interface):
		_setup_editor_connection()


func _exit_tree() -> void:
	# Disconnect from the editor's selection system.
	if is_instance_valid(_editor_interface):
		var selection := _editor_interface.get_selection()
		if selection and selection.is_connected("selection_changed", _on_selection_changed):
			selection.selection_changed.disconnect(_on_selection_changed)
	
	# Disconnect from the current node.
	_disconnect_from_node()


func _on_selection_changed() -> void:
	_update_for_selected_node()


func _setup_editor_connection() -> void:
	var selection := _editor_interface.get_selection()
	if selection:
		if not selection.is_connected("selection_changed", _on_selection_changed):
			selection.selection_changed.connect(_on_selection_changed)

	# Initial state.
	_update_for_selected_node()


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


func _update_for_selected_node() -> void:
	_disconnect_from_node()

	var selection := _editor_interface.get_selection()
	var selected_nodes: Array = []
	if selection:
		selected_nodes = selection.get_selected_nodes()

	_current_node = null

	if selected_nodes.size() > 0 and selected_nodes[0] is AIChat:
		_current_node = selected_nodes[0] as AIChat

		# Connect signals from the node.
		_current_node.connect("chat_started", _on_chat_started)
		_current_node.connect("progress", _on_node_progress)
		_current_node.connect("chat_finished", _on_chat_finished)
		_current_node.connect("chat_error", _on_chat_error)

		# Refresh UI state.
		_update_display()
		_status_label.text = "Status: Ready"
	else:
		_history_display.text = ""
		_status_label.text = "No AIChat selected"
		_progress_bar.value = 0.0
		_update_theme_colors() # Reset to neutral


# --- Send / Cancel / Clear ---

func _on_send_pressed() -> void:
	if is_instance_valid(_current_node):
		var prompt := _input_text_edit.text.strip_edges()
		if prompt.is_empty():
			return
		
		_input_text_edit.text = ""
		_current_node.send_message(prompt)
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
		_update_display()


# --- Node Signals ---

func _on_chat_started() -> void:
	_status_label.text = "Status: Typing..."
	_send_button.disabled = true
	_cancel_button.disabled = false
	_update_theme_colors()


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
	_update_theme_colors()


func _on_chat_error(err: String) -> void:
	_status_label.text = "Status: Error - " + err
	_send_button.disabled = false
	_cancel_button.disabled = true
	_update_theme_colors()


# --- Display ---

func _update_display() -> void:
	if not is_instance_valid(_current_node):
		return

	_history_display.clear()
	
	for msg in _current_node.chat_history:
		var role: String = msg.role.capitalize()
		var color: String = "#4285f4" if msg.role == "user" else "#34a853"
		
		_history_display.push_color(Color(color))
		_history_display.add_text("[%s]: " % role)
		_history_display.pop()
		
		_history_display.add_text(msg.content + "\n\n")
	
	# Show partial response if currently typing.
	if not _current_node.partial_response.is_empty():
		_history_display.push_color(Color("#34a853"))
		_history_display.add_text("[Assistant]: ")
		_history_display.pop()
		_history_display.add_text(_current_node.partial_response)


func _update_theme_colors() -> void:
	if not is_instance_valid(_editor_interface):
		return

	var base := _editor_interface.get_base_control()
	var theme := base.theme
	
	if not is_instance_valid(_current_node):
		_status_label.remove_theme_color_override("font_color")
		return

	if _send_button.disabled: # Simple check for "busy"
		_status_label.add_theme_color_override("font_color", theme.get_color("warning_color", "Editor"))
	elif _status_label.text.contains("Error"):
		_status_label.add_theme_color_override("font_color", theme.get_color("error_color", "Editor"))
	elif _status_label.text.contains("Finished"):
		_status_label.add_theme_color_override("font_color", theme.get_color("success_color", "Editor"))
	else:
		_status_label.remove_theme_color_override("font_color")
