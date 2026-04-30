## AgentAssisted3D - Custom 3D node that generates a scene subtree via AI.
##
## When added to a scene with a non-empty [member prompt], the node sends the
## prompt (and optional [member texture_attachments]) to an AI backend,
## executes the generated GDScript, and applies the resulting node hierarchy
## as direct children. Results are saved to `res://generated/`.

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
var prompt: String = ""

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


# --- Lifecycle ---

func _ready() -> void:
	# If children already exist (from scene file restore), reuse them.
	if get_child_count() > 0:
		generation_status = GenerationStatus.SUCCESS
		status_message = "Using cached scene nodes"
		return


# --- Generation pipeline ---

func generate() -> void:
	generation_status = GenerationStatus.GENERATING
	status_message = "Generating..."
	generation_started.emit()

	# Build initial prompt.
	var messages := PromptBuilder.build(prompt, texture_attachments)
	var script_text: String = ""
	var success: bool = false

	# Error-correction loop.
	for attempt in range(MAX_RETRIES):
		# Call AI.
		script_text = await _call_ai(messages)
		status_message = "Generating... (attempt %d/%d)" % [attempt + 1, MAX_RETRIES]

		# Execute script.
		var error_result := ScriptExecutor.execute_with_error(script_text, self)

		if error_result.error == null:
			success = true
			break

		# Append error to chat history.
		status_message = "Fixing error on attempt %d/%d: %s" % [attempt + 1, MAX_RETRIES, error_result.error]
		messages = PromptBuilder.build_error_correction(messages, error_result, script_text)

	if success:
		_save_generated_script(script_text)
		_apply_generated_nodes(script_text)
		generation_status = GenerationStatus.SUCCESS
		status_message = "Generation complete"
	else:
		generation_status = GenerationStatus.ERROR
		status_message = "Generation failed after %d attempts" % MAX_RETRIES

	generation_finished.emit()


# --- AI call ---

func _call_ai(messages: Array[Dictionary]) -> String:
	var endpoint: String = api_endpoint if api_endpoint != "" else _get_project_setting("base_url", "http://localhost:1234/v1")
	var key: String = api_key if api_key != "" else _get_project_setting("api_key", "")
	var model_name: String = model if model != "" else _get_project_setting("model", "")
	var max_tokens: int = _get_project_setting("max_tokens", 4096)

	var client := AIClient.create_openai_client()
	add_child(client)
	
	# Relay progress signal to the editor dock
	client.progress.connect(func(chunks: Array[String]): progress.emit(chunks))
	
	client.set_endpoint(endpoint)
	if key != "":
		client.set_api_key(key)
	if model_name != "":
		client.set_model(model_name)
	client.set_max_tokens(max_tokens)

	var response := await client.chat_stream(messages)
	client.queue_free()
	return response


# --- Cache helpers ---

# --- Persistence helpers ---

func _save_generated_script(script_text: String) -> void:
	var dir := "res://generated/"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var path := "res://generated/%s_last_generation.gd" % name
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(script_text)
		file.close()


# --- Node application ---

func _apply_generated_nodes(script_text: String) -> void:
	# Clear existing generated children.
	for child in get_children():
		child.queue_free()

	# Execute the script to build the node tree.
	if script_text != "":
		var error_result := ScriptExecutor.execute_with_error(script_text, self)
		if error_result.error != null:
			push_error("Failed to apply generated script: %s" % error_result.error)
			return

		# Set owner for all new children to ensure they are saved with the scene.
		var edited_root := get_tree().get_edited_scene_root()
		if edited_root:
			for child in get_children():
				_set_owner_recursive(child, edited_root)


func _set_owner_recursive(node: Node, scene_owner: Node) -> void:
	node.owner = scene_owner
	for child in node.get_children():
		_set_owner_recursive(child, scene_owner)


# --- Helpers ---

func _get_project_setting(key: String, default: Variant = null) -> Variant:
	var full_key := "ai/openai/%s" % key
	return ProjectSettings.get_setting(full_key, default)
