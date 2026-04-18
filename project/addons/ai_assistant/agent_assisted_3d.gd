## AgentAssisted3D - Custom 3D node that generates a scene subtree via AI.
##
## Properties:
##   prompt            - Multiline text prompt for generation
##   texture_attachments - Array of Texture2D attachments
##   generation_status  - IDLE, GENERATING, SUCCESS, ERROR
##   status_message     - Human-readable status text
##   api_endpoint       - Override for ai/openai/base_url
##   api_key            - Override for ai/openai/api_key
##   model              - Override for ai/openai/model

@tool
extends Node3D


class_name AgentAssisted3D


enum GenerationStatus {
	IDLE = 0,
	GENERATING = 1,
	SUCCESS = 2,
	ERROR = 3,
}


signal generation_started()
signal generation_finished()
signal progress(chunks: Array[String])


@export_group("AI Assistant")

@export_multiline
var prompt: String = "":
	set(val):
		prompt = val
		if _prompt_changed():
			_on_prompt_changed()
	get:
		return prompt

@export
var texture_attachments: Array[Texture2D] = []

@export
var generation_status: GenerationStatus = GenerationStatus.IDLE

@export
var status_message: String = ""

@export
var api_endpoint: String = "":
	set(val):
		api_endpoint = val
	get:
		return val if val != "" else _get_project_setting("base_url")

@export
var api_key: String = "":
	set(val):
		api_key = val
	get:
		return val if val != "" else _get_project_setting("api_key")

@export
var model: String = "":
	set(val):
		model = val
	get:
		return val if val != "" else _get_project_setting("model")


var _prompt_hash: String = ""
var _instance_id: String = ""
var _generated_nodes: Array[Node] = []


func _ready() -> void:
	if prompt != "" and generation_status == GenerationStatus.IDLE:
		if not _has_valid_cache():
			generate()


func _get_scene_path_hash() -> String:
	var scene_path = get_tree().edited_scene_root.get_path() if get_tree().edited_scene_root else NodePath()
	var full_path = str(scene_path) + "/" + get_path()
	return _md5(full_path)


func _generate_instance_id() -> String:
	_instance_id = _get_scene_path_hash()
	return _instance_id


func _prompt_changed() -> bool:
	var new_hash = _md5(prompt)
	if new_hash != _prompt_hash:
		_prompt_hash = new_hash
		return true
	return false


func _on_prompt_changed() -> void:
	if generation_status != GenerationStatus.GENERATING:
		_invalidate_cache()
		generate()


func generate() -> void:
	generation_status = GenerationStatus.GENERATING
	status_message = "Generating..."
	generation_started.emit()

	var messages = _build_prompt()
	var script_text = await _call_ai(messages)

	if script_text == "":
		_on_generation_failed("Empty response from AI")
		return

	_apply_generated_script(script_text)
	_save_cache(script_text)

	generation_status = GenerationStatus.SUCCESS
	status_message = "Generation complete"
	generation_finished.emit()


func force_generate() -> void:
	_invalidate_cache()
	generate()


func _build_prompt() -> Array[Dictionary]:
	var system_prompt = ProjectSettings.get_setting("ai/openai/system_prompt", "")
	if system_prompt == "":
		system_prompt = (
			"You are a Godot 4 scene generation assistant.\n"
			"Given a user prompt and optional visual references,\n"
			"generate GDScript code that creates a node hierarchy.\n\n"
			"Rules:\n"
			"- Output ONLY valid GDScript code, no markdown fences\n"
			"- Use Node3D, MeshInstance3D, DirectionalLight3D, etc.\n"
			"- Set reasonable default properties (position, scale, material)\n"
			"- Use clear variable names and add helpful comments\n"
			"- The root node should be a Node3D with the script attached\n"
			"- Use standard Godot 4 API (no deprecated methods)\n"
			"- Keep the scene performant and well-organized\n"
		)

	var user_content = prompt
	if texture_attachments.size() > 0:
		user_content += "\n\nVisual references attached below."

	var messages: Array[Dictionary] = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": user_content},
	]

	return messages


func _call_ai(messages: Array[Dictionary]) -> String:
	var endpoint = api_endpoint
	if endpoint == "":
		endpoint = ProjectSettings.get_setting("ai/openai/base_url", "http://localhost:1234/v1")

	var key = api_key
	if key == "":
		key = ProjectSettings.get_setting("ai/openai/api_key", "")

	var model_name = model
	if model_name == "":
		model_name = ProjectSettings.get_setting("ai/openai/model", "local-model")

	var max_tokens = ProjectSettings.get_setting("ai/openai/max_tokens", 4096)

	var body = {
		"model": model_name,
		"messages": messages,
		"max_tokens": max_tokens,
	}

	var headers = ["Content-Type: application/json"]
	if key != "":
		headers.append("Authorization: Bearer " + key)

	var http_request = HTTPRequest.new()
	add_child(http_request)

	var error = http_request.request(
		endpoint + "/v1/chat/completions",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)

	if error != OK:
		_on_generation_failed("HTTP request failed: %d" % error)
		http_request.queue_free()
		return ""

	var response = await http_request.request_completed

	http_request.queue_free()

	var result = JSON.parse_string(response[3])
	if result == null or "choices" not in result or result["choices"].size() == 0:
		_on_generation_failed("Invalid AI response")
		return ""

	return result["choices"][0]["message"]["content"]


func _apply_generated_script(script_text: String) -> void:
	clear_generated_nodes()

	var gdscript = GDScript.new()
	gdscript.source_code = script_text

	var compile_result = gdscript.compile()
	if compile_result != OK:
		_on_generation_failed("GDScript compilation error: %d" % compile_result)
		return

	var instance = gdscript.new()
	if instance and instance.has_method("_build_scene"):
		_generated_nodes = instance._build_scene(self)
	else:
		_on_generation_failed("Generated script has no _build_scene method")
		return

	for child in _generated_nodes:
		add_child(child)
		if get_tree().edited_scene_root:
			child.set_owner(get_tree().edited_scene_root)


func _save_cache(script_text: String) -> void:
	var cache_dir = "res://generated/%s/" % _get_instance_id()
	_make_dir_recursive(cache_dir)

	var cache_path = "res://generated/%s/current.gd" % _get_instance_id()

	var gdscript = GDScript.new()
	gdscript.source_code = script_text
	gdscript.set_meta("prompt_hash", _md5(prompt))
	gdscript.set_meta("generated_at", Time.get_datetime_string_from_system())

	ResourceSaver.save(cache_path, gdscript)


func _has_valid_cache() -> bool:
	var cache_path = "res://generated/%s/current.gd" % _get_instance_id()
	if not ResourceLoader.exists(cache_path):
		return false

	var cached_script = load(cache_path)
	if cached_script == null:
		return false

	var cached_hash = cached_script.get_meta("prompt_hash", "")
	var current_hash = _md5(prompt)
	return cached_hash == current_hash


func _load_from_cache() -> void:
	var cache_path = "res://generated/%s/current.gd" % _get_instance_id()
	var cached_script = load(cache_path)

	if cached_script == null:
		generate()
		return

	var instance = cached_script.new()
	if instance and instance.has_method("_build_scene"):
		_generated_nodes = instance._build_scene(self)
		for child in _generated_nodes:
			add_child(child)
			if get_tree().edited_scene_root:
				child.set_owner(get_tree().edited_scene_root)

	generation_status = GenerationStatus.SUCCESS
	status_message = "Loaded from cache"
	generation_finished.emit()


func _invalidate_cache() -> void:
	var cache_path = "res://generated/%s/current.gd" % _get_instance_id()
	if DirAccess.file_exists(cache_path):
		DirAccess.remove_absolute(cache_path)


func _on_generation_failed(message: String) -> void:
	generation_status = GenerationStatus.ERROR
	status_message = message
	push_error("AgentAssisted3D generation failed: " + message)


func clear_generated_nodes() -> void:
	for child in get_children():
		child.queue_free()
	_generated_nodes = []


func get_generated_nodes() -> Array[Node]:
	return _generated_nodes


func _get_instance_id() -> String:
	if _instance_id == "":
		_generate_instance_id()
	return _instance_id


func _get_project_setting(key: String) -> String:
	return ProjectSettings.get_setting("ai/openai/" + key, "")


func _make_dir_recursive(path: String) -> void:
	var dir = DirAccess.open("res://")
	if dir == null:
		return

	var parts = path.split("/", false)
	var current = "res://"
	for part in parts:
		if part == "":
			continue
		current += "/" + part
		if not dir.dir_exists(current):
			dir.make_dir(current)


func _md5(text: String) -> String:
	var bytes = Marshalls.string_to_utf8(text)
	var hash = HashingContext.hash_bytes(bytes, HashingContext.HASH_MD5)
	return bytes_to_hex_string(hash)
