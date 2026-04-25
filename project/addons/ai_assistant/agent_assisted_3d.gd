## AgentAssisted3D - Custom 3D node that generates a scene subtree via AI.
##
## When added to a scene with a non-empty [member prompt], the node sends the
## prompt (and optional [member texture_attachments]) to an AI backend,
## executes the generated GDScript, and applies the resulting node hierarchy
## as direct children. Results are cached in `res://generated/<instance_id>/`.

@tool
extends Node3D


class_name AgentAssisted3D


const MAX_RETRIES: int = 5


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
var api_endpoint: String = ""

@export
var api_key: String = ""

@export
var model: String = ""


# --- Internal state ---

var _prompt_hash: int = 0
var _instance_id: String = ""
var _current_script_text: String = ""


# --- Lifecycle ---

func _ready() -> void:
	# If children already exist (from scene file restore), reuse them.
	if get_child_count() > 0:
		generation_status = GenerationStatus.SUCCESS
		status_message = "Using cached scene nodes"
		return

	# Check for cached generation.
	if _has_valid_cache():
		_load_from_cache()
		return

	# Auto-generate if prompt is non-empty.
	if prompt != "":
		generate()


# --- Generation pipeline ---

func generate() -> void:
	generation_status = GenerationStatus.GENERATING
	status_message = "Generating..."
	generation_started.emit()

	# Check cache first.
	if _has_valid_cache():
		_load_from_cache()
		generation_status = GenerationStatus.SUCCESS
		status_message = "Loaded from cache"
		generation_finished.emit()
		return

	# Build initial prompt.
	var messages := PromptBuilder.build(prompt, texture_attachments)
	var script_text: String = ""
	var success: bool = false

	# Error-correction loop.
	for attempt in range(MAX_RETRIES):
		# Call AI.
		script_text = await _call_ai(messages)
		_current_script_text = script_text
		status_message = "Generating... (attempt %d/%d)" % [attempt + 1, MAX_RETRIES]

		# Execute script.
		var error_result := await ScriptExecutor.execute_with_error(script_text, self)

		if error_result.error == null:
			success = true
			break

		# Append error to chat history.
		status_message = "Fixing error on attempt %d/%d: %s" % [attempt + 1, MAX_RETRIES, error_result.error]
		messages = PromptBuilder.build_error_correction(messages, error_result, script_text)

	if success:
		_save_cache(script_text)
		_apply_generated_nodes()
		generation_status = GenerationStatus.SUCCESS
		status_message = "Generation complete"
	else:
		generation_status = GenerationStatus.ERROR
		status_message = "Generation failed after %d attempts" % MAX_RETRIES

	generation_finished.emit()


func force_generate() -> void:
	_invalidate_cache()
	generate()


# --- AI call ---

func _call_ai(messages: Array[Dictionary]) -> String:
	var endpoint: String = api_endpoint if api_endpoint != "" else _get_project_setting("base_url", "http://localhost:1234/v1")
	var key: String = api_key if api_key != "" else _get_project_setting("api_key", "")
	var model_name: String = model if model != "" else _get_project_setting("model", "")
	var max_tokens: int = _get_project_setting("max_tokens", 4096)

	var client := AIClient.create_openai_client()
	client.set_endpoint(endpoint)
	if key != "":
		client.set_api_key(key)
	if model_name != "":
		client.set_model(model_name)
	client.set_max_tokens(max_tokens)

	var response := await client.chat(messages)
	return response


# --- Cache helpers ---

func _get_instance_id() -> String:
	if _instance_id == "":
		_instance_id = _get_scene_path_hash()
	return _instance_id


func _get_scene_path_hash() -> String:
	var scene_path: String = ""
	var edited_root := get_tree().edited_scene_root
	if edited_root:
		scene_path = edited_root.get_path().get_concatenated_names()
	var full_path: String = scene_path + "/" + get_path().get_concatenated_names()
	return str(hash(full_path))


func _get_cache_path() -> String:
	return "res://generated/%s/current.gd" % _get_instance_id()


func _has_valid_cache() -> bool:
	var cache_path := _get_cache_path()
	if not ResourceLoader.exists(cache_path):
		return false

	var cached_script = load(cache_path) as GDScript
	if cached_script == null:
		return false

	var cached_hash: int = cached_script.get_meta("prompt_hash", 0)
	var current_hash: int = hash(prompt)
	return cached_hash == current_hash


func _save_cache(script_text: String) -> void:
	var cache_dir := "res://generated/%s/" % _get_instance_id()
	DirAccess.make_dir_recursive_absolute(cache_dir)

	var cache_path := _get_cache_path()

	var gdscript := GDScript.new()
	gdscript.source_code = script_text
	gdscript.set_meta("prompt_hash", hash(prompt))
	gdscript.set_meta("generated_at", Time.get_datetime_string_from_system())

	ResourceSaver.save(gdscript, cache_path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)


func _load_from_cache() -> void:
	var cache_path := _get_cache_path()
	var cached_script = load(cache_path) as GDScript

	if cached_script == null:
		generate()
		return

	_current_script_text = cached_script.source_code
	_apply_generated_nodes()


func _invalidate_cache() -> void:
	var cache_path := _get_cache_path()
	var da := DirAccess.open("res://")
	if da and da.file_exists(cache_path):
		da.remove(cache_path)


# --- Node application ---

func _apply_generated_nodes() -> void:
	# Clear existing generated children.
	for child in get_children():
		child.queue_free()

	# Re-execute the cached/last script to rebuild the node tree.
	if _current_script_text != "":
		var error_result := ScriptExecutor.execute_with_error(_current_script_text, self)
		if error_result.error != null:
			push_error("Failed to apply cached script: %s" % error_result.error)
			return


# --- Prompt change detection ---

func _prompt_changed() -> bool:
	var new_hash: int = hash(prompt)
	if new_hash != _prompt_hash:
		_prompt_hash = new_hash
		return true
	return false


func _on_prompt_changed() -> void:
	if generation_status != GenerationStatus.GENERATING:
		_invalidate_cache()
		generate()


# --- Helpers ---

func _get_project_setting(key: String, default: Variant = null) -> Variant:
	var full_key := "ai/openai/%s" % key
	return ProjectSettings.get_setting(full_key, default)
