## AIAgentAssisted3DPanel - Editor dock UI controller for the AIAgentAssisted3D node.
##
## Connects to the currently selected AIAgentAssisted3D node in the editor,
## provides two-way prompt binding, progress tracking, texture drag-and-drop,
## and a live preview of generated output and errors.

@tool
extends ScrollContainer


var _current_node: AIAgentAssisted3D = null
var _editor_interface: EditorInterface

# UI node references
@onready var _prompt_text_edit: TextEdit = find_child("PromptTextEdit")
@onready var _mode_selector: OptionButton = find_child("ModeSelector")
@onready var _send_button: Button = find_child("SendButton")
@onready var _cancel_button: Button = find_child("CancelButton")
@onready var _clear_button: Button = find_child("ClearButton")
@onready var _status_label: Label = find_child("StatusLabel")
@onready var _progress_bar: ProgressBar = find_child("ProgressBar")
@onready var _code_view: CodeEdit = find_child("GeneratedOutput")
@onready var _error_text_edit: TextEdit = find_child("ErrorTextEdit")
@onready var _drop_label: Label = find_child("DropLabel")
@onready var _attachments_container: VBoxContainer = find_child("AttachmentsContainer")


# Called by the plugin after instantiation to inject the EditorInterface.
func _init_editor(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


func _ready() -> void:
	# Enable drag-and-drop on the attachments container.
	if _attachments_container:
		_attachments_container.set_drag_forwarding(
			Callable(self, "_can_drop_data"),
			Callable(self, "_drop_data"),
			Callable(self, "_get_drag_data"),
		)

	# Connect UI signals.
	if _prompt_text_edit:
		_prompt_text_edit.text_changed.connect(_on_prompt_text_edit_text_changed)
	if _mode_selector:
		_mode_selector.item_selected.connect(_on_mode_selected)
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
		if _current_node.is_connected("progress", _on_node_progress):
			_current_node.disconnect("progress", _on_node_progress)
		if _current_node.is_connected("code_updated", _on_node_code_updated):
			_current_node.disconnect("code_updated", _on_node_code_updated)


func _update_for_selected_node() -> void:
	_disconnect_from_node()

	var selection := _editor_interface.get_selection()
	var selected_nodes: Array = []
	if selection:
		selected_nodes = selection.get_selected_nodes()

	_current_node = null

	if selected_nodes.size() > 0 and selected_nodes[0] is AIAgentAssisted3D:
		_current_node = selected_nodes[0] as AIAgentAssisted3D

		# Sync properties.
		_prompt_text_edit.text = _current_node.prompt
		_mode_selector.selected = _current_node.generation_mode

		# Connect signals from the node.
		_current_node.connect("progress", _on_node_progress)
		_current_node.connect("code_updated", _on_node_code_updated)

		# Refresh UI state.
		_refresh_attachments()
		_code_view.text = _current_node.generated_code
		_error_text_edit.text = _current_node.last_error
		_update_status()
	else:
		_prompt_text_edit.text = ""
		_status_label.text = "No AIAgentAssisted3D selected"
		_progress_bar.value = 0.0
		_code_view.text = ""
		_error_text_edit.text = ""
		_drop_label.visible = true
		_update_theme_colors() # Reset to neutral


# --- Mode / Prompt sync ---

func _on_mode_selected(index: int) -> void:
	if is_instance_valid(_current_node):
		_current_node.generation_mode = index as AIAgentAssisted3D.GenerationMode


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


# --- Progress / Output display ---

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

	var status: AIAgentAssisted3D.GenerationStatus = _current_node.generation_status
	var message: String = _current_node.status_message

	# Toggle button states
	var generating := (status == AIAgentAssisted3D.GenerationStatus.GENERATING)
	_send_button.disabled = generating
	_cancel_button.disabled = not generating
	_clear_button.disabled = generating

	_update_theme_colors()

	_error_text_edit.text = _current_node.last_error

	match status:
		AIAgentAssisted3D.GenerationStatus.IDLE:
			_status_label.text = "Status: Idle"
			_progress_bar.value = 0.0
		AIAgentAssisted3D.GenerationStatus.GENERATING:
			_status_label.text = message
		AIAgentAssisted3D.GenerationStatus.SUCCESS:
			_status_label.text = "Status: " + message
			_progress_bar.value = 100.0
		AIAgentAssisted3D.GenerationStatus.ERROR:
			_status_label.text = "Status: " + message


func _update_theme_colors() -> void:
	if not is_instance_valid(_editor_interface):
		return

	var base := _editor_interface.get_base_control()
	var theme := base.theme
	
	if not is_instance_valid(_current_node):
		_status_label.remove_theme_color_override("font_color")
		return

	var status: AIAgentAssisted3D.GenerationStatus = _current_node.generation_status
	match status:
		AIAgentAssisted3D.GenerationStatus.GENERATING:
			_status_label.add_theme_color_override("font_color", theme.get_color("warning_color", "Editor"))
		AIAgentAssisted3D.GenerationStatus.SUCCESS:
			_status_label.add_theme_color_override("font_color", theme.get_color("success_color", "Editor"))
		AIAgentAssisted3D.GenerationStatus.ERROR:
			_status_label.add_theme_color_override("font_color", theme.get_color("error_color", "Editor"))
		_:
			_status_label.remove_theme_color_override("font_color")


# --- Drag & drop for texture attachments ---

var TEXTURE_EXTENSIONS: PackedStringArray = PackedStringArray([
	"png", "jpg", "jpeg", "bmp", "webp",
])


func _get_drag_data(position: Vector2) -> Variant:
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

	# Remove any existing texture preview labels (skip DropLabel).
	for child in _attachments_container.get_children():
		if child is Label and child != _drop_label:
			child.queue_free()

	_drop_label.visible = (_current_node.texture_attachments.is_empty())

	for texture in _current_node.texture_attachments:
		var name_label := Label.new()
		name_label.text = texture.resource_path.get_file()
		_attachments_container.add_child(name_label)


# --- Helpers ---

func _estimate_tokens(text: String) -> int:
	if text.is_empty():
		return 0
	return int(len(text) / 4.0)
