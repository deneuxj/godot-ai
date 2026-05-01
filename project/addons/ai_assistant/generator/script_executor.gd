## ScriptExecutor - Validates AI-generated GDScript or TSCN files.
##
## Performs parse and load validation to ensure generated content is usable
## by Godot without requiring arbitrary execution.

class_name ScriptExecutor


## Validate AI output based on the generation mode.
##
## Returns `{"error": null}` on success, or
## `{"error": String}` on failure.
static func validate_output(content: String, mode: int) -> Dictionary:
	# Enum mapping (must match AgentAssisted3D.GenerationMode)
	if mode == 0: # SCENE
		return _validate_tscn(content)
	else: # NODE_SCRIPT
		return _validate_gdscript(content)


## Basic parse validation for Godot TSCN files.
static func _validate_tscn(content: String) -> Dictionary:
	if not content.begins_with("[gd_scene") and not content.begins_with("[gd_resource"):
		return {"error": "Invalid TSCN format: Must start with [gd_scene or [gd_resource"}

	# Attempt to load the scene via a temporary file.
	var temp_path := "res://generated/temp_validation.tscn"
	var dir := "res://generated/"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		return {"error": "Failed to create temp file for validation"}
	
	file.store_string(content)
	file.close()
	
	# Try to load it as a resource.
	var scene = ResourceLoader.load(temp_path)
	
	# Cleanup immediately.
	DirAccess.remove_absolute(temp_path)
	
	if scene == null:
		return {"error": "Failed to load TSCN: Godot ResourceLoader returned null"}
	
	return {"error": null}


## Compilation check for GDScript.
static func _validate_gdscript(content: String) -> Dictionary:
	if not content.contains("extends Node3D"):
		return {"error": "Script must extend Node3D"}

	var gdscript := GDScript.new()
	gdscript.source_code = content
	
	# reload() parses the script and checks for syntax errors.
	var err := gdscript.reload()
	if err != OK:
		return {"error": "GDScript parse error (code %d)" % err}
	
	return {"error": null}
