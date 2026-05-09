## AIBasePanel - Base class for AI-related editor docks.
##
## Handles common editor integration tasks:
## - EditorInterface injection
## - Selection change tracking
## - Theme color retrieval
## - Token estimation

@tool
extends ScrollContainer

class_name AIBasePanel


var _editor_interface: EditorInterface


## Called by the plugin after instantiation to inject the EditorInterface.
func _init_editor(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


func _ready() -> void:
	# Connect to the editor's selection system.
	if is_instance_valid(_editor_interface):
		_setup_editor_connection()
	
	_on_ready()


func _exit_tree() -> void:
	# Disconnect from the editor's selection system.
	if is_instance_valid(_editor_interface):
		var selection := _editor_interface.get_selection()
		if selection and selection.is_connected("selection_changed", _on_selection_changed):
			selection.selection_changed.disconnect(_on_selection_changed)
	
	_on_exit_tree()


## Virtual method for subclasses to implement initialization logic.
func _on_ready() -> void:
	pass


## Virtual method for subclasses to implement cleanup logic.
func _on_exit_tree() -> void:
	pass


func _setup_editor_connection() -> void:
	var selection := _editor_interface.get_selection()
	if selection:
		if not selection.is_connected("selection_changed", _on_selection_changed):
			selection.selection_changed.connect(_on_selection_changed)

	# Initial state.
	_on_selection_changed()


func _on_selection_changed() -> void:
	var selection := _editor_interface.get_selection()
	var selected_nodes: Array = []
	if selection:
		selected_nodes = selection.get_selected_nodes()

	var target_node: Node = null
	if selected_nodes.size() > 0:
		target_node = selected_nodes[0]

	_update_for_node(target_node)


## Virtual method for subclasses to implement node-specific UI updates.
func _update_for_node(_node: Node) -> void:
	pass


## Helper to get standard editor colors based on status.
func _get_status_color(status_type: String) -> Color:
	if not is_instance_valid(_editor_interface):
		return Color.WHITE

	var base := _editor_interface.get_base_control()
	if not is_instance_valid(base):
		return Color.WHITE
	
	match status_type.to_lower():
		"warning", "busy", "generating", "typing":
			return base.get_theme_color("warning_color", "Editor")
		"success", "finished", "idle":
			return base.get_theme_color("success_color", "Editor")
		"error":
			return base.get_theme_color("error_color", "Editor")
		_:
			return base.get_theme_color("font_color", "Editor")


## Helper to estimate token count (approx. 4 chars per token).
func _estimate_tokens(text: String) -> int:
	if text.is_empty():
		return 0
	return int(len(text) / 4.0)
