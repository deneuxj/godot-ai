## AgentAssisted3DPanel - Editor dock UI controller for the AgentAssisted3D node.

extends Control


var _current_node: AgentAssisted3D = null
var _prompt_text_edit: TextEdit
var _status_label: Label
var _progress_bar: ProgressBar
var _node_tree_view: Tree
var _generate_button: Button
var _attachments_container: VBoxContainer


func _ready() -> void:
	_prompt_text_edit = $VBoxContainer/PromptTextEdit
	_status_label = $VBoxContainer/StatusRow/StatusLabel
	_progress_bar = $VBoxContainer/StatusRow/ProgressBar
	_node_tree_view = $VBoxContainer/NodeTreeView
	_generate_button = $VBoxContainer/GenerateRow/GenerateButton

	_prompt_text_edit.text_changed.connect(_on_prompt_text_changed)
	_generate_button.pressed.connect(_on_generate_pressed)

	_update_for_selected_node()


func _on_selection_changed() -> void:
	var editor_interface = get_editor_interface()
	if editor_interface == null:
		return
	var selected = editor_interface.get_selection().get_selected_nodes()
	if selected.size() > 0:
		_update_for_selected_node()
	elif _current_node == null:
		_status_label.text = "No AgentAssisted3D selected"


func _update_for_selected_node() -> void:
	var editor_interface = get_editor_interface()
	if editor_interface == null:
		return

	var selected = editor_interface.get_selection().get_selected_nodes()

	if _current_node:
		if _current_node.has_signal("progress"):
			_current_node.disconnect("progress", self, "_on_node_progress")
		if _current_node.has_signal("generation_started"):
			_current_node.disconnect("generation_started", self, "_on_generation_started")
		if _current_node.has_signal("generation_finished"):
			_current_node.disconnect("generation_finished", self, "_on_generation_finished")

	_current_node = null

	if selected.size() > 0 and selected[0] is AgentAssisted3D:
		_current_node = selected[0] as AgentAssisted3D
		_prompt_text_edit.text = _current_node.prompt
		_current_node.connect("progress", self, "_on_node_progress")
		_current_node.connect("generation_started", self, "_on_generation_started")
		_current_node.connect("generation_finished", self, "_on_generation_finished")
		_refresh_status()
		_refresh_attachments()
		_refresh_node_tree()
	else:
		_prompt_text_edit.text = ""
		_status_label.text = "No AgentAssisted3D selected"
		_status_label.add_theme_color_override("font_color", Color.GRAY)
		_progress_bar.value = 0.0
		_node_tree_view.clear()


func _on_generate_pressed() -> void:
	if _current_node:
		_current_node.force_generate()


func _on_prompt_text_changed() -> void:
	if _current_node:
		_current_node.prompt = _prompt_text_edit.text


func _on_node_progress(chunks: Array[String]) -> void:
	var text = chunks.join("")
	var token_count = _estimate_tokens(text)
	_status_label.text = "Generating... (%d tokens)" % token_count
	_status_label.add_theme_color_override("font_color", Color.BLUE)
	_progress_bar.value = min(100.0, float(token_count) / 40.0)


func _on_generation_started() -> void:
	_status_label.text = "Generating..."
	_status_label.add_theme_color_override("font_color", Color.ORANGE)
	_progress_bar.value = 0.0


func _on_generation_finished() -> void:
	_refresh_status()
	_refresh_node_tree()


func _refresh_status() -> void:
	if _current_node == null:
		return

	match _current_node.generation_status:
		AgentAssisted3D.GenerationStatus.IDLE:
			_status_label.text = "Status: Idle"
			_status_label.add_theme_color_override("font_color", Color.DIM_GRAY)
			_progress_bar.value = 0.0
		AgentAssisted3D.GenerationStatus.GENERATING:
			_status_label.text = "Status: Generating..."
			_status_label.add_theme_color_override("font_color", Color.ORANGE)
		AgentAssisted3D.GenerationStatus.SUCCESS:
			_status_label.text = "Status: " + _current_node.status_message
			_status_label.add_theme_color_override("font_color", Color.GREEN)
			_progress_bar.value = 100.0
		AgentAssisted3D.GenerationStatus.ERROR:
			_status_label.text = "Error: " + _current_node.status_message
			_status_label.add_theme_color_override("font_color", Color.RED)


func _refresh_attachments() -> void:
	for child in _attachments_container.get_children():
		if child != $VBoxContainer/AttachmentsContainer/DropLabel:
			child.queue_free()

	if _current_node == null or _current_node.texture_attachments.size() == 0:
		$VBoxContainer/AttachmentsContainer/DropLabel.visible = true
		return

	$VBoxContainer/AttachmentsContainer/DropLabel.visible = false

	for texture in _current_node.texture_attachments:
		var h_box = HBoxContainer.new()
		var label = Label.new()
		label.text = texture.resource_path.get_file()
		h_box.add_child(label)

		var remove_btn = Button.new()
		remove_btn.text = "x"
		remove_btn.pressed.connect(_on_remove_attachment.bind(texture))
		h_box.add_child(remove_btn)

		_attachments_container.add_child(h_box)


func _refresh_node_tree() -> void:
	_node_tree_view.clear()

	if _current_node == null:
		return

	var root = _node_tree_view.create_item()
	root.set_text(0, "AgentAssisted3D")

	var generated = _current_node.get_generated_nodes()
	for child in generated:
		var item = _node_tree_view.create_item(root)
		item.set_text(0, child.name + " (" + child.get_class() + ")")
		for grandchild in child.get_children():
			var sub = _node_tree_view.create_item(item)
			sub.set_text(0, grandchild.name + " (" + grandchild.get_class() + ")")


func _on_remove_attachment(texture: Texture2D) -> void:
	if _current_node == null:
		return

	var idx = _current_node.texture_attachments.find(texture)
	if idx >= 0:
		_current_node.texture_attachments.remove_at(idx)
		_refresh_attachments()


func _can_drop_data(position: Vector2, data: Variant) -> bool:
	if not typeof(data) == TYPE_DICTIONARY:
		return false
	if not "files" in data:
		return false

	for file in data["files"]:
		var ext = file.get_extension().to_lower()
		if ext in ["png", "jpg", "jpeg", "bmp", "webp"]:
			return true
	return false


func _drop_data(position: Vector2, data: Variant) -> void:
	if not typeof(data) == TYPE_DICTIONARY:
		return
	if not "files" in data:
		return

	var textures: Array[Texture2D] = []
	for file in data["files"]:
		var texture = load(file)
		if texture is Texture2D:
			textures.append(texture)

	if _current_node != null:
		for texture in textures:
			if not texture in _current_node.texture_attachments:
				_current_node.texture_attachments.append(texture)
		_refresh_attachments()


func _estimate_tokens(text: String) -> int:
	return max(1, int(len(text) / 4.0))
