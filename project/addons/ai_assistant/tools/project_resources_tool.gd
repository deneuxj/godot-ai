## ProjectResourcesTool - Allows the AI to explore the project's resources.

class_name ProjectResourcesTool
extends AITool


func _init() -> void:
	super._init("explore_project_resources", "List files and directories in the project. Retrieve basic metadata or content of a specific resource.")


func get_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"command": {
				"type": "string",
				"enum": ["list_files", "get_file_content", "search"],
				"description": "The command to execute. 'get_file_content' has a 32,000 character limit per call."
			},
			"path": {
				"type": "string",
				"description": "The directory path or file path."
			},
			"query": {
				"type": "string",
				"description": "Search keyword for filenames."
			},
			"start_line": {
				"type": "integer",
				"description": "The 1-based line number to start reading from (inclusive).",
				"minimum": 1
			},
			"end_line": {
				"type": "integer",
				"description": "The 1-based line number to stop reading at (inclusive). Use -1 for end of file.",
				"default": -1
			}
		},
		"required": ["command"]
	}


func execute(arguments: Dictionary) -> String:
	var command = arguments.get("command", "")
	var path = arguments.get("path", "res://")
	var query = arguments.get("query", "")
	var start_line = int(arguments.get("start_line", 1))
	var end_line = int(arguments.get("end_line", -1))

	match command:
		"list_files":
			return _list_files(path)
		"get_file_content":
			return _get_file_content(path, start_line, end_line)
		"search":
			return _search(query)
		_:
			return "Error: Unknown command " + command


func _list_files(path: String) -> String:
	if not path.begins_with("res://"):
		path = "res://" + path
	
	var dir = DirAccess.open(path)
	if not dir:
		return "Error: Could not open path '%s'." % path
	
	dir.list_dir_begin()
	var files = []
	var dirs = []
	
	var item = dir.get_next()
	while item != "":
		if dir.current_is_dir():
			dirs.append(item + "/")
		else:
			files.append(item)
		item = dir.get_next()
	
	dirs.sort()
	files.sort()
	
	var result = "Contents of %s:\n" % path
	if not dirs.is_empty():
		result += "Directories: " + ", ".join(dirs) + "\n"
	if not files.is_empty():
		result += "Files: " + ", ".join(files)
	
	if dirs.is_empty() and files.is_empty():
		result = "Directory %s is empty." % path
		
	return result


func _get_file_content(path: String, start_line: int = 1, end_line: int = -1) -> String:
	if not path.begins_with("res://"):
		path = "res://" + path
		
	if not FileAccess.file_exists(path):
		return "Error: File '%s' does not exist." % path
	
	# Only read text-based files
	var ext = path.get_extension().to_lower()
	var text_extensions = ["gd", "tscn", "tres", "txt", "md", "json", "xml", "cfg"]
	
	if ext not in text_extensions:
		return "Info: Resource '%s' is a binary file (extension: %s). Metadata only: Size: %d bytes" % [path, ext, FileAccess.open(path, FileAccess.READ).get_length()]

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return "Error: Could not read file '%s'." % path
		
	var lines := []
	while not file.eof_reached():
		lines.append(file.get_line())
	
	# Remove last empty line if it was just EOF
	if not lines.is_empty() and lines.back().is_empty() and file.eof_reached():
		lines.pop_back()

	var total_lines = lines.size()
	
	# Clamp and adjust start/end lines
	start_line = clampi(start_line, 1, total_lines)
	if end_line == -1 or end_line > total_lines:
		end_line = total_lines
	
	if start_line > end_line:
		return "Error: start_line (%d) is greater than end_line (%d). Total lines: %d" % [start_line, end_line, total_lines]

	var slice = lines.slice(start_line - 1, end_line)
	var content = "\n".join(slice)
	
	var range_info = ""
	if start_line > 1 or end_line < total_lines:
		range_info = " (lines %d to %d of %d)" % [start_line, end_line, total_lines]
	
	# Enforce size limit to prevent context overflow
	if content.length() > 32000:
		return "Error: Requested content size (%d characters) is too large. Please read a smaller section using 'start_line' and 'end_line' parameters. Total lines in file: %d" % [content.length(), total_lines]
		
	return "Content of %s%s:\n```\n%s\n```" % [path, range_info, content]


func _search(query: String) -> String:
	if query.is_empty():
		return "Error: Search query is empty."
	
	var results = []
	_search_recursive("res://", query, results)
	
	if results.is_empty():
		return "Error: No resources found matching '%s'." % query
	
	if results.size() > 30:
		return "Found %d results for '%s'. Here are the first 30:\n" % [results.size(), query] + "\n".join(results.slice(0, 30))
		
	return "Search results for '%s':\n" % query + "\n".join(results)


func _search_recursive(path: String, query: String, results: Array) -> void:
	if results.size() > 50: return
	
	var dir = DirAccess.open(path)
	if not dir: return
	
	dir.list_dir_begin()
	var item = dir.get_next()
	while item != "":
		if item.begins_with("."):
			item = dir.get_next()
			continue
			
		var full_path = path
		if not full_path.ends_with("/"):
			full_path += "/"
		full_path += item
		
		if dir.current_is_dir():
			_search_recursive(full_path, query, results)
		else:
			if query.to_lower() in item.to_lower():
				results.append(full_path)
				
		item = dir.get_next()
