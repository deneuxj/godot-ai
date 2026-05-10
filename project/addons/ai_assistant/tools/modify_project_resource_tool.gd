## ModifyProjectResourceTool - Allows the AI to create or patch project files.

class_name ModifyProjectResourceTool
extends AITool


func _init() -> void:
	super._init("modify_project_resource", "Create new files or patch existing ones with safety checks. Use for surgical edits.")


func get_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"path": {
				"type": "string",
				"description": "The res:// path to the file to create or modify."
			},
			"target_line": {
				"type": "integer",
				"description": "The 1-based line number where the old_content is expected to start.",
				"minimum": 1
			},
			"old_content": {
				"type": "string",
				"description": "The exact text block expected to be replaced. MUST match the file content for the patch to succeed. Use an empty string for new files."
			},
			"new_content": {
				"type": "string",
				"description": "The new text block to insert at the target location."
			}
		},
		"required": ["path", "target_line", "old_content", "new_content"]
	}


func execute(arguments: Dictionary) -> String:
	var path = arguments.get("path", "")
	var target_line = int(arguments.get("target_line", 1))
	var old_content = arguments.get("old_content", "")
	var new_content = arguments.get("new_content", "")

	if not path.begins_with("res://"):
		path = "res://" + path

	if not FileAccess.file_exists(path):
		if old_content.is_empty():
			return _create_new_file(path, new_content)
		else:
			return "Error: File '%s' does not exist and old_content was not empty." % path

	return _patch_existing_file(path, target_line, old_content, new_content)


func _create_new_file(path: String, content: String) -> String:
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var err = DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			return "Error: Could not create directory structure for '%s' (Error code: %d)." % [path, err]

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return "Error: Could not open file '%s' for writing." % path

	file.store_string(content)
	return "Success: Created new file '%s'." % path


func _patch_existing_file(path: String, target_line: int, old_content: String, new_content: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return "Error: Could not open file '%s' for reading." % path

	var lines := []
	while not file.eof_reached():
		lines.append(file.get_line())
	
	# Remove last empty line if it was just EOF
	if not lines.is_empty() and lines.back().is_empty() and file.eof_reached():
		lines.pop_back()

	var total_lines = lines.size()
	var old_lines = old_content.split("\n")
	var old_line_count = old_lines.size()

	# Search for old_content in a window around target_line (+/- 5 lines)
	var found_at = -1
	for offset in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5]:
		var current_start = target_line + offset
		if current_start < 1 or current_start + old_line_count - 1 > total_lines:
			continue
		
		var match_found = true
		for i in range(old_line_count):
			if lines[current_start + i - 1] != old_lines[i]:
				match_found = false
				break
		
		if match_found:
			found_at = current_start
			break

	if found_at == -1:
		# Provide context of what IS at the target_line to help the AI recalibrate
		var actual_context := []
		var context_start = clampi(target_line, 1, total_lines)
		var context_end = clampi(target_line + old_line_count - 1, 1, total_lines)
		for i in range(context_start, context_end + 1):
			actual_context.append(lines[i-1])
		
		var error_msg = "Error: old_content mismatch at %s:%d.\n" % [path, target_line]
		error_msg += "Expected first line: '%s'\n" % old_lines[0]
		error_msg += "Actual lines at that location:\n```\n%s\n```\n" % "\n".join(actual_context)
		error_msg += "Please read the file again to ensure you have the latest content before retrying."
		return error_msg

	# Apply the patch
	var new_lines = lines.duplicate()
	new_lines.remove_at(found_at - 1, old_line_count) # Godot 4.x remove_at doesn't have count?
	# Correction: Godot 4 Array.remove_at(index) only removes ONE element. 
	# Need to call it multiple times or use slice/concat.
	
	var result_lines := []
	for i in range(found_at - 1):
		result_lines.append(lines[i])
	
	result_lines.append_array(new_content.split("\n"))
	
	for i in range(found_at - 1 + old_line_count, total_lines):
		result_lines.append(lines[i])

	var write_file = FileAccess.open(path, FileAccess.WRITE)
	if not write_file:
		return "Error: Could not open file '%s' for writing." % path

	write_file.store_string("\n".join(result_lines))
	return "Success: Modified file '%s' at line %d." % [path, found_at]
