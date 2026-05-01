## AgentAssisted3D - Custom 3D node that generates scenes or scripts via AI.
##
## The AI can generate either a full scene (.tscn) to be instantiated as a child,
## or a GDScript (.gd) to be attached directly to this node.
## Results are saved to `res://generated/`.

@tool
extends Node3D


class_name AgentAssisted3D


enum GenerationStatus {
	IDLE = 0,
	GENERATING = 1,
	SUCCESS = 2,
	ERROR = 3,
}

enum GenerationMode {
	SCENE = 0,
	NODE_SCRIPT = 1,
}


signal generation_started()
signal generation_finished()
signal progress(chunks: Array[String])
signal code_updated(code: String)


@export_group("AI Assistant")

@export
var generation_mode: GenerationMode = GenerationMode.SCENE

@export_multiline
var prompt: String = ""

@export
var texture_attachments: Array[Texture2D] = []

@export
var generation_status: GenerationStatus = GenerationStatus.IDLE

@export
var status_message: String = ""

@export_multiline
var generated_code: String = ""

@export
var api_endpoint: String = ""

@export
var api_key: String = ""

@export
var model: String = ""


# --- Internal state ---

var _active_client: AIClient = null


# --- Lifecycle ---

func _ready() -> void:
	# If children already exist (from scene file restore), reuse them.
	if get_child_count() > 0:
		generation_status = GenerationStatus.SUCCESS
		status_message = "Using cached scene nodes"
		return
	
	# If a script is already attached (besides this tool script), assume success.
	if get_script() != null and get_script().resource_path != "res://addons/ai_assistant/agent_assisted_3d.gd":
		generation_status = GenerationStatus.SUCCESS
		status_message = "Using attached script"
		return


# --- Generation pipeline ---

func generate() -> void:
	generation_status = GenerationStatus.GENERATING
	status_message = "Generating..."
	generation_started.emit()

	# 1. Build initial prompt.
	var messages := PromptBuilder.build(prompt, texture_attachments, generation_mode)
	var content: String = ""
	var success: bool = false
	
	var max_retries: int = _get_project_setting("max_retries", 5)

	# 2. AI & Validation Loop
	for attempt in range(max_retries):
		# Call AI.
		content = await _call_ai(messages)
		
		# Immediately update the code property so the user can see it (even on error).
		generated_code = content
		code_updated.emit(generated_code)
		
		if generation_status == GenerationStatus.IDLE:
			# Cancelled.
			return
		
		status_message = "Generating... (attempt %d/%d)" % [attempt + 1, max_retries]

		# 3. Validate output (Parse check only, no execution)
		var error_result := ScriptExecutor.validate_output(content, generation_mode)

		if error_result.error == null:
			success = true
			break
		
		if generation_status == GenerationStatus.IDLE:
			# Cancelled during validation.
			return

		# 4. Error correction: Append error to chat history.
		status_message = "Fixing error on attempt %d/%d: %s" % [attempt + 1, max_retries, error_result.error]
		messages = PromptBuilder.build_error_correction(messages, error_result, content)

	if success:
		# 5. Save and Apply
		var path := _save_generated_output(content, generation_mode)
		_apply_generated_output(path, generation_mode)
		
		generation_status = GenerationStatus.SUCCESS
		status_message = "Generation complete"
	elif generation_status != GenerationStatus.IDLE:
		generation_status = GenerationStatus.ERROR
		status_message = "Generation failed after %d attempts" % max_retries

	generation_finished.emit()


func cancel_generation() -> void:
	if is_instance_valid(_active_client):
		_active_client.cancel()
	
	generation_status = GenerationStatus.IDLE
	status_message = "Generation cancelled"
	generation_finished.emit()


# --- AI call ---

func _call_ai(messages: Array[Dictionary]) -> String:
	var endpoint: String = api_endpoint if api_endpoint != "" else _get_project_setting("base_url", "http://localhost:1234/v1")
	var key: String = api_key if api_key != "" else _get_project_setting("api_key", "")
	var model_name: String = model if model != "" else _get_project_setting("model", "")
	var max_tokens: int = _get_project_setting("max_tokens", 4096)

	var client := AIClient.create_openai_client()
	add_child(client)
	_active_client = client
	
	# Relay progress signal to the editor dock
	client.progress.connect(func(chunks: Array[String]): progress.emit(chunks))
	
	client.set_endpoint(endpoint)
	if key != "":
		client.set_api_key(key)
	if model_name != "":
		client.set_model(model_name)
	client.set_max_tokens(max_tokens)

	var response := await client.chat_stream(messages)
	
	if is_instance_valid(client):
		client.queue_free()
	
	if _active_client == client:
		_active_client = null
		
	return response


# --- Persistence helpers ---

func _save_generated_output(content: String, mode: GenerationMode) -> String:
	var dir := "res://generated/"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var ext := ".tscn" if mode == GenerationMode.SCENE else ".gd"
	var path := "res://generated/%s%s" % [name, ext]
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
	
	return path


# --- Result application ---

func _apply_generated_output(path: String, mode: GenerationMode) -> void:
	if mode == GenerationMode.SCENE:
		# Clear existing generated children.
		for child in get_children():
			child.queue_free()
		
		# Load and instantiate the scene.
		var scene = load(path) as PackedScene
		if scene:
			var instance = scene.instantiate()
			add_child(instance)
			
			# Set owner for the instance and all its children so they are saved with the scene.
			var edited_root := get_tree().get_edited_scene_root()
			if edited_root:
				_set_owner_recursive(instance, edited_root)
	
	elif mode == GenerationMode.NODE_SCRIPT:
		# Load and attach the script to this node.
		var script = load(path) as Script
		if script:
			# Note: In Godot 4, set_script() might not be enough in @tool mode
			# if we want the node to instantly change behavior in editor.
			set_script(script)


func _set_owner_recursive(node: Node, scene_owner: Node) -> void:
	node.owner = scene_owner
	for child in node.get_children():
		_set_owner_recursive(child, scene_owner)


# --- Helpers ---

func _get_project_setting(key: String, default: Variant = null) -> Variant:
	var full_key := "ai/openai/%s" % key
	return ProjectSettings.get_setting(full_key, default)
