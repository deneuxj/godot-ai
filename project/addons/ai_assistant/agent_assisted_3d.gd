## AgentAssisted3D - Custom 3D node that generates scenes or scripts via AI.
##
## The AI can generate either a full scene (.tscn) to be instantiated as a child,
## or a GDScript (.gd) to be attached directly to this node.
## Results are saved to `res://generated/`.

@tool
extends Node3D


class_name AIAgentAssisted3D

const AISettings = preload("res://addons/ai_assistant/settings/ai_settings.gd")


enum GenerationStatus {
	IDLE = 0,
	GENERATING = 1,
	SUCCESS = 2,
	ERROR = 3,
}

enum GenerationMode {
	SCENE = 0,
	SCRIPTED_SCENE = 1,
	NODE_SCRIPT = 2,
}


signal generation_started()
signal generation_finished()
signal progress(chunks: Array[String])
signal code_updated(code: String)
signal status_updated(message: String)


@export_group("Input")

@export_multiline
var prompt: String = ""

@export
var texture_attachments: Array[Texture2D] = []

@export_group("Settings")

@export
var generation_mode: GenerationMode = GenerationMode.SCENE

@export
var generated_node_name: String = "GeneratedNode"

@export_group("Output Control")

## Directory where the generated file will be saved.
@export_global_dir
var output_directory: String = "res://generated/"

## Filename (without extension) for the generated file. If empty, uses the node's name.
@export
var output_filename: String = ""

@export_group("API Overrides (Advanced)")

@export
var api_endpoint: String = ""

@export
var api_key: String = ""

@export
var model: String = ""

@export_group("Last Result")

@export_multiline
var last_error: String = "":
	set(value):
		last_error = value
		status_updated.emit(status_message)

@export_multiline
var generated_code: String = ""


# --- Internal status tracking (not exported) ---

var generation_status: GenerationStatus = GenerationStatus.IDLE
var status_message: String = "":
	set(value):
		status_message = value
		status_updated.emit(value)
var _active_client: AIClient = null


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
	status_message = "Processing..."
	last_error = ""
	generated_code = ""
	generation_started.emit()

	# 1. Build initial prompt.
	var messages := PromptBuilder.build(prompt, texture_attachments, generation_mode)
	var content: String = ""
	var success: bool = false
	
	var max_retries: int = AISettings.get_int(AISettings.GEN, "max_retries")

	# 2. AI & Validation Loop
	for attempt in range(max_retries):
		# Call AI.
		status_message = "Generating... (attempt %d/%d)" % [attempt + 1, max_retries]
		content = await _call_ai(messages)
		
		# Immediately update the code property so the user can see it.
		var extracted_code := ScriptExecutor.extract_code(content)
		generated_code = extracted_code
		code_updated.emit(generated_code)
		
		if generation_status == GenerationStatus.IDLE:
			return # Cancelled.
		
		# Clear previous error before validation and force visibility.
		last_error = ""
		status_message = "Validating... (attempt %d/%d)" % [attempt + 1, max_retries]

		# 3. Validate output (Async)
		var error_result := await ScriptExecutor.validate_output(extracted_code, generation_mode)

		if error_result.error == null:
			success = true
			if generation_mode == GenerationMode.SCRIPTED_SCENE and error_result.has("root"):
				# Save the root node for serialization later.
				var root: Node3D = error_result.root
				var dir := output_directory
				if not dir.ends_with("/"):
					dir += "/"
				var file_name := output_filename if not output_filename.is_empty() else name
				var path := "%s%s.tscn" % [dir, file_name]
				
				var err := ScriptExecutor.serialize_to_tscn(root, path)
				root.free() # Clean up the temporary hierarchy
				
				if err != OK:
					success = false
					error_result.error = "Failed to serialize node hierarchy to TSCN (error code %d). Check your 'owner' assignments." % err
				else:
					break # Success!
			else:
				break
		
		if generation_status == GenerationStatus.IDLE:
			return # Cancelled during validation.

		# 4. Error correction: Update error and loop.
		last_error = error_result.error
		status_message = "Fixing error... (attempt %d/%d)" % [attempt + 1, max_retries]
		messages = PromptBuilder.build_error_correction(messages, error_result, content)

	if success:
		# 5. Save and Apply
		var path := _save_generated_output(generated_code, generation_mode)
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
	var endpoint: String = api_endpoint if api_endpoint != "" else AISettings.get_string(AISettings.CONN, "base_url")
	var key: String = api_key if api_key != "" else AISettings.get_string(AISettings.CONN, "api_key")
	var model_name: String = model if model != "" else AISettings.get_string(AISettings.CONN, "model")
	var max_tokens: int = AISettings.get_int(AISettings.GEN, "max_tokens")

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

	var response = await client.chat_stream(messages)
	
	if is_instance_valid(client):
		client.queue_free()
	
	if _active_client == client:
		_active_client = null
		
	return response


# --- Persistence helpers ---

func _save_generated_output(content: String, mode: GenerationMode) -> String:
	var dir := output_directory
	if not dir.ends_with("/"):
		dir += "/"
		
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var ext := ".tscn" if mode == GenerationMode.SCENE else ".gd"
	var file_name := output_filename
	if file_name.is_empty():
		file_name = name
		
	var path := "%s%s%s" % [dir, file_name, ext]
	
	# For SCRIPTED_SCENE, we already saved the .tscn via serialize_to_tscn
	if mode == GenerationMode.SCRIPTED_SCENE:
		return path

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
	
	return path


# --- Result application ---

func _apply_generated_output(path: String, mode: GenerationMode) -> void:
	if mode == GenerationMode.SCENE or mode == GenerationMode.SCRIPTED_SCENE:
		# Clear existing generated children.
		for child in get_children():
			child.queue_free()
		
		# Load and instantiate the scene.
		var scene = load(path) as PackedScene
		if scene:
			var instance = scene.instantiate()
			instance.name = generated_node_name
			add_child(instance)
			
			# Set owner for the instance and all its children so they are saved with the scene.
			var edited_root := get_tree().get_edited_scene_root()
			if edited_root:
				_set_owner_recursive(instance, edited_root)
	
	elif mode == GenerationMode.NODE_SCRIPT:
		# Clear existing generated children.
		for child in get_children():
			child.queue_free()
		
		# Load and attach the script to a new child node.
		var script = load(path) as Script
		if script:
			var instance = Node3D.new()
			instance.name = generated_node_name
			instance.set_script(script)
			add_child(instance)
			
			# Set owner so it is saved with the scene.
			var edited_root := get_tree().get_edited_scene_root()
			if edited_root:
				instance.owner = edited_root


func _set_owner_recursive(node: Node, scene_owner: Node) -> void:
	node.owner = scene_owner
	for child in node.get_children():
		_set_owner_recursive(child, scene_owner)


# --- Helpers ---
