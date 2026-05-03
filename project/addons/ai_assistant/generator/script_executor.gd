## ScriptExecutor - Validates AI-generated GDScript or TSCN files.
##
## Performs parse and load validation for AI-generated content.
## Uses ResourceLoader for TSCN and GDScript.reload() for scripts.

class_name ScriptExecutor

static var _logger_instance: Logger = null

static func register_logger(logger: Logger) -> void:
	_logger_instance = logger


static func _get_logger() -> Logger:
	return _logger_instance


## Extract code content from markdown code blocks if present.
static func extract_code(content: String) -> String:
	if not content.contains("```"):
		return content.strip_edges()
	
	var lines = content.split("\n")
	var inside_block = false
	var extracted_lines = []
	
	for line in lines:
		var stripped = line.strip_edges()
		if stripped.begins_with("```"):
			if not inside_block:
				inside_block = true
				continue # Skip the opening fence
			else:
				break # Found the closing fence, we're done
		
		if inside_block:
			extracted_lines.append(line)
			
	if extracted_lines.size() > 0:
		return "\n".join(extracted_lines).strip_edges()
	
	return content.strip_edges()


## Validate AI output based on the generation mode.
##
## Returns `{"error": null}` on success, or
## `{"error": String}` on failure.
static func validate_output(content: String, mode: int) -> Dictionary:
	var logger = _get_logger()
	if logger:
		logger.call("start_capture")

	var code = extract_code(content)

	var result: Dictionary
	if mode == 0: # SCENE
		result = await _validate_tscn(code)
	elif mode == 1: # SCRIPTED_SCENE
		result = await _validate_scripted_scene(code)
	else: # NODE_SCRIPT
		result = await _validate_gdscript(code)

	if logger:
		logger.call("stop_capture")
		if result.error != null:
			var extra = logger.call("get_captured_errors")
			if extra != "":
				result.error += "\nEngine Errors:\n" + extra

	return result


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
	
	# Try to load it as a resource (Asynchronously).
	var err = ResourceLoader.load_threaded_request(temp_path)
	if err != OK:
		DirAccess.remove_absolute(temp_path)
		return {"error": "Failed to initiate background TSCN load: %d" % err}
	
	# Wait for loading to complete.
	var status = ResourceLoader.load_threaded_get_status(temp_path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await Engine.get_main_loop().process_frame
		status = ResourceLoader.load_threaded_get_status(temp_path)
	
	var scene = ResourceLoader.load_threaded_get(temp_path)
	
	if scene == null:
		# Error will be captured by the logger.
		DirAccess.remove_absolute(temp_path)
		return {"error": "Failed to load TSCN: Godot ResourceLoader returned null."}
	
	# Cleanup.
	DirAccess.remove_absolute(temp_path)
	return {"error": null}


## Validate and execute a construction script to build a scene.
static func _validate_scripted_scene(content: String) -> Dictionary:
	# 1. Basic parse check
	var gdscript := GDScript.new()
	gdscript.source_code = content
	var parse_err := gdscript.reload()
	if parse_err != OK:
		return {"error": "GDScript parse error code: %d" % parse_err}

	# 2. Instantiate and execute
	var obj = gdscript.new()
	if not obj:
		return {"error": "Failed to instantiate construction script."}
	
	if not obj.has_method("build"):
		return {"error": "Script missing mandatory 'build() -> Node3D' method."}
	
	var root = obj.call("build")
	if not (root is Node3D):
		if root is Node:
			root.free() # Clean up invalid node type
		return {"error": "build() must return a Node3D (got %s)." % (type_string(typeof(root)) if root else "null")}

	# Success: return the root node so it can be serialized.
	return {"error": null, "root": root}


## Validation for GDScript using standard engine mechanisms.
static func _validate_gdscript(content: String) -> Dictionary:
	if not content.contains("extends Node3D"):
		return {"error": "Script must extend Node3D"}

	var gdscript := GDScript.new()
	gdscript.source_code = content
	var err := gdscript.reload()
	if err != OK:
		return {"error": "GDScript parse error (code %d)." % err}
	
	return {"error": null}


## Serialize a node hierarchy to a .tscn file.
static func serialize_to_tscn(root: Node3D, path: String) -> Error:
	if not root:
		return ERR_INVALID_PARAMETER

	# 1. Recursively set owner for all children
	_set_owner_recursive(root, root)

	# 2. Pack the scene
	var packed_scene := PackedScene.new()
	var pack_err := packed_scene.pack(root)
	if pack_err != OK:
		return pack_err

	# 3. Save to disk
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	
	return ResourceSaver.save(packed_scene, path)


static func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)
