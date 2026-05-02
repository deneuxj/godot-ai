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
	if mode == 1: # SCENE
		result = _validate_tscn(code)
	else: # NODE_SCRIPT
		result = _validate_gdscript(code)

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
	
	# Try to load it as a resource.
	var scene = ResourceLoader.load(temp_path)
	
	if scene == null:
		# Error will be captured by the logger.
		var err_msg = "Failed to load TSCN: Godot ResourceLoader returned null."
		
		# Fallback: Try headless validation if available for more details.
		var headless_err = _validate_tscn_headless(temp_path)
		if headless_err != "":
			err_msg += "\nHeadless Validation Errors:\n" + headless_err
			
		DirAccess.remove_absolute(temp_path)
		return {"error": err_msg}
	
	# Cleanup.
	DirAccess.remove_absolute(temp_path)
	return {"error": null}


## Headless validation using the Godot editor.
static func _validate_tscn_headless(tscn_path: String) -> String:
	var godot_path := "/home/johann/Godot/godot.sh"
	if not FileAccess.file_exists(godot_path):
		return ""

	var project_dir = ProjectSettings.globalize_path("res://")
	var output = []
	# Use timeout to prevent hanging.
	var args = ["--headless", "--path", project_dir, "-e"]
	
	# We use OS.execute to run godot. Since we want to capture stderr, 
	# and OS.execute might only capture stdout depending on implementation,
	# we wrap it in a shell to redirect 2>&1.
	var command = "timeout 15 %s %s 2>&1" % [godot_path, " ".join(args)]
	var exit_code = OS.execute("bash", ["-c", command], output, true)
	
	var full_output = "".join(output)
	var errors = []
	for line in full_output.split("\n"):
		if line.contains("ERROR:") or line.contains("SCRIPT ERROR:") or line.contains("Parse Error:"):
			# Filter out irrelevant environment warnings.
			if not line.contains("Locale not supported"):
				errors.append(line.strip_edges())
				
	return "\n".join(errors)


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
	
	var output = []
	var args = [script_path, "--project-root", project_root, temp_path]
	
	# Execute the LSP checker.
	var exit_code = OS.execute("python3", args, output, true)
	
	# Cleanup.
	DirAccess.remove_absolute(temp_path)

	if exit_code == 0:
		return {"error": null}
	elif exit_code == 1:
		# Return the formatted LSP report.
		var report = "".join(output)
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
