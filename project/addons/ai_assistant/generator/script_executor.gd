## ScriptExecutor - Validates AI-generated GDScript or TSCN files.
##
## Performs parse and load validation using the Godot Language Server (LSP)
## for GDScript and ResourceLoader for TSCN.

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


## Advanced validation for GDScript using the Godot Language Server.
static func _validate_gdscript(content: String) -> Dictionary:
	if not content.contains("extends Node3D"):
		return {"error": "Script must extend Node3D"}

	# Save to temp file for LSP check.
	var temp_path := "res://generated/temp_validation.gd"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		return {"error": "Failed to create temp file for validation"}
	file.store_string(content)
	file.close()

	# Get project paths.
	var project_root = ProjectSettings.globalize_path("res://")
	# Use absolute path to the qwen skill script.
	var script_path = project_root + "../.qwen/skills/godot-lsp/scripts/gdscript_check.py"
	
	var res = {"exit_code": -1, "output": []}
	var args = [script_path, "--project-root", project_root, temp_path]
	
	# Execute the LSP checker in a background thread to avoid freezing.
	var thread = Thread.new()
	var thread_err = thread.start(func(): 
		res.exit_code = OS.execute("python3", args, res.output, true)
	)
	
	if thread_err != OK:
		DirAccess.remove_absolute(temp_path)
		return {"error": "Failed to start validation thread: %d" % thread_err}
	
	while thread.is_alive():
		await Engine.get_main_loop().process_frame
		
	thread.wait_to_finish()
	
	# Cleanup.
	DirAccess.remove_absolute(temp_path)

	if res.exit_code == 0:
		return {"error": null}
	elif res.exit_code == 1:
		# Return the formatted LSP report.
		var report = "".join(res.output)
		return {"error": "GDScript validation failed:\n" + report}
	else:
		# Connection error (LSP not running).
		# Fallback to basic reload() check.
		var gdscript := GDScript.new()
		gdscript.source_code = content
		var err := gdscript.reload()
		if err != OK:
			return {"error": "GDScript parse error (code %d). Note: LSP connection failed." % err}
		return {"error": null}
