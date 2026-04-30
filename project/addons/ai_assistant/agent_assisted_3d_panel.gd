## AgentAssisted3DPanel - Editor dock UI controller for the AgentAssisted3D node.
##
## Connects to the currently selected AgentAssisted3D node in the editor,
## provides two-way prompt binding, progress tracking, texture drag-and-drop,
## and a live node tree preview of generated children.

@tool
extends Control


var _current_node: AgentAssisted3D = null
var _editor_interface: EditorInterface

# UI node references (set in _ready)
var _prompt_text_edit: TextEdit
var _send_button: Button
var _cancel_button: Button
var _clear_button: Button
var _status_label: Label
var _progress_bar: ProgressBar
var _tab_container: TabContainer
var _node_tree: Tree
var _code_view: CodeEdit
var _drop_label: Label


# Called by the plugin after instantiation to inject the EditorInterface.
func _init_editor(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


func _ready() -> void:
	# Cache references to UI nodes by name.
	_prompt_text_edit = $VBoxContainer/PromptTextEdit as TextEdit
	_send_button = $VBoxContainer/GenerateRow/SendButton as Button
	_cancel_button = $VBoxContainer/GenerateRow/CancelButton as Button
	_clear_button = $VBoxContainer/GenerateRow/ClearButton as Button
	_status_label = $VBoxContainer/StatusRow/StatusLabel as Label
	_progress_bar = $VBoxContainer/StatusRow/ProgressBar as ProgressBar
	_tab_container = $VBoxContainer/TabContainer as TabContainer
	_node_tree = $"VBoxContainer/TabContainer/Node Tree" as Tree
	_code_view = $"VBoxContainer/TabContainer/Generated Code" as CodeEdit
	_drop_label = $VBoxContainer/AttachmentsContainer/DropLabel as Label

	# Enable drag-and-drop on the attachments container.
	$VBoxContainer/AttachmentsContainer.set_drag_forwarding(
		Callable(self, "_can_drop_data"),
		Callable(self, "_drop_data"),
		Callable(self, "_get_drag_data"),
	)

	# Connect UI signals.
	_prompt_text_edit.text_changed.connect(_on_prompt_text_edit_text_changed)
	_send_button.pressed.connect(_on_send_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_clear_button.pressed.connect(_on_clear_pressed)

	# Connect to the editor's selection system and initialize.
	# Use call_deferred to ensure the editor is fully ready.
	if is_instance_valid(_editor_interface):
		_setup_editor_connection()


func _on_selection_changed() -> void:
	_update_for_selected_node()


func _setup_editor_connection() -> void:
	var selection := _editor_interface.get_selection()
	if selection:
		selection.selection_changed.connect(_on_selection_changed)

	# Initial state.
	_update_for_selected_node()


func _update_for_selected_node() -> void:
	# Disconnect signals from the old node.
	if is_instance_valid(_current_node):
		_current_node.disconnect("progress", _on_node_progress)
		if _current_node.is_connected("code_updated", _on_node_code_updated):
			_current_node.disconnect("code_updated", _on_node_code_updated)

	var selection := _editor_interface.get_selection()
	var selected_nodes: Array = []
	if selection:
		selected_nodes = selection.get_selected_nodes()

	_current_node = null

	if selected_nodes.size() > 0 and selected_nodes[0] is AgentAssisted3D:
		_current_node = selected_nodes[0] as AgentAssisted3D

		# Two-way prompt binding.
		_prompt_text_edit.text = _current_node.prompt

		# Connect signals from the node.
		_current_node.connect("progress", _on_node_progress)
		_current_node.connect("code_updated", _on_node_code_updated)

		# Refresh UI state.
		_refresh_attachments()
		_refresh_node_tree()
		_code_view.text = _current_node.generated_code
		_update_status()
	else:
		_prompt_text_edit.text = ""
		_status_label.text = "No AgentAssisted3D selected"
		_progress_bar.value = 0.0
		_node_tree.clear()
		_code_view.text = ""
		_drop_label.visible = true


# --- Prompt sync ---

func _on_prompt_text_edit_text_changed() -> void:
	if is_instance_valid(_current_node):
		_current_node.prompt = _prompt_text_edit.text


# --- Send / Cancel / Clear ---

func _on_send_pressed() -> void:
	if is_instance_valid(_current_node):
		_current_node.generate()
		_update_status()


func _on_cancel_pressed() -> void:
	if is_instance_valid(_current_node):
		_current_node.cancel_generation()
		_update_status()


func _on_clear_pressed() -> void:
	if is_instance_valid(_current_node):
		_current_node.prompt = ""
		_prompt_text_edit.text = ""


# --- Progress / Code display ---

func _on_node_progress(_chunks: Array[String]) -> void:
	if not is_instance_valid(_current_node):
		return

	# Estimate token count from chunk content.
	var total_text: String = "".join(_chunks)
	var estimated_tokens: int = _estimate_tokens(total_text)

	_status_label.text = "Generating... (%d tokens)" % estimated_tokens
	# Rough progress estimate: assume ~40 tokens per progress-bar unit.
	_progress_bar.value = min(100.0, float(estimated_tokens) / 40.0)

	_update_status()


func _on_node_code_updated(code: String) -> void:
	_code_view.text = code


# --- Status binding ---

func _update_status() -> void:
	if not is_instance_valid(_current_node):
		return

	var status: AgentAssisted3D.GenerationStatus = _current_node.generation_status
	var message: String = _current_node.status_message

	# Toggle button states
	var generating := (status == AgentAssisted3D.GenerationStatus.GENERATING)
	_send_button.disabled = generating
	_cancel_button.disabled = not generating
	_clear_button.disabled = generating

	match status:
		AgentAssisted3D.GenerationStatus.IDLE:
			_status_label.text = "Status: Idle"
			_status_label.add_theme_color_override("font_color", Color.WHITE)
			_progress_bar.value = 0.0
		AgentAssisted3D.GenerationStatus.GENERATING:
			# Already set by _on_node_progress or initial state.
			_status_label.add_theme_color_override("font_color", Color.YELLOW)
		AgentAssisted3D.GenerationStatus.SUCCESS:
			_status_label.text = "Status: " + message
			_status_label.add_theme_color_override("font_color", Color.GREEN)
			_progress_bar.value = 100.0
			_refresh_node_tree()
		AgentAssisted3D.GenerationStatus.ERROR:
			_status_label.text = "Status: " + message
			_status_label.add_theme_color_override("font_color", Color.RED)


# --- Drag & drop for texture attachments ---

var TEXTURE_EXTENSIONS: PackedStringArray = PackedStringArray([
	"png", "jpg", "jpeg", "bmp", "webp",
])


func _get_drag_data(position: Vector2) -> Variant:
	# Return an empty dictionary to enable drop targeting.
	# Actual file data is provided by _can_drop_data checking.
	return {}


func _can_drop_data(position: Vector2, data: Variant) -> bool:
	if not is_instance_valid(data):
		return false

	if typeof(data) != TYPE_DICTIONARY:
		return false

	var data_dict: Dictionary = data as Dictionary
	if not "files" in data_dict:
		return false

	var files: PackedStringArray = data_dict["files"] as PackedStringArray
	for file_path: String in files:
		var ext: String = file_path.get_extension().to_lower()
		if ext in TEXTURE_EXTENSIONS:
			return true

	return false


func _drop_data(position: Vector2, data: Variant) -> void:
	if not is_instance_valid(data):
		return

	if typeof(data) != TYPE_DICTIONARY:
		return

	var data_dict: Dictionary = data as Dictionary
	if not "files" in data_dict:
		return

	var files: PackedStringArray = data_dict["files"] as PackedStringArray
	var textures: Array[Texture2D] = []

	for file_path: String in files:
		var ext: String = file_path.get_extension().to_lower()
		if ext not in TEXTURE_EXTENSIONS:
			continue

		var resource: Variant = load(file_path)
		if resource is Texture2D:
			textures.append(resource as Texture2D)

	if is_instance_valid(_current_node):
		_current_node.texture_attachments = textures
		_refresh_attachments()


# --- Attachments display ---

func _refresh_attachments() -> void:
	if not is_instance_valid(_current_node):
		_drop_label.visible = true
		return

	var attachments_container := $VBoxContainer/AttachmentsContainer
	# Remove any existing texture preview labels (skip DropLabel).
	for child in attachments_container.get_children():
		if child is Label and child != _drop_label:
			child.queue_free()

	_drop_label.visible = (_current_node.texture_attachments.is_empty())

	for texture in _current_node.texture_attachments:
		var name_label := Label.new()
		name_label.text = texture.resource_path.get_file()
		attachments_container.add_child(name_label)


# --- Node tree preview ---

func _refresh_node_tree() -> void:
	_node_tree.clear()

	if not is_instance_valid(_current_node):
		return

	var root := _node_tree.create_item()
	root.set_text(0, "AgentAssisted3D")

	for child in _current_node.get_children():
		_add_node_to_tree(child, root)


func _add_node_to_tree(node: Node, parent_item: TreeItem) -> void:
	var item := _node_tree.create_item(parent_item)
	var node_name: String = node.name
	var node_type: String = node.get_class()
	item.set_text(0, "%s (%s)" % [node_name, node_type])

	for child in node.get_children():
		_add_node_to_tree(child, item)


# --- Helpers ---

func _estimate_tokens(text: String) -> int:
	# Rough token estimation: ~4 chars per token (English average).
	if text.is_empty():
		return 0
	return int(len(text) / 4.0)
