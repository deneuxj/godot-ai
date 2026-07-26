## SearchProjectFilesTool - Allows the AI to search for strings or regex within project files
# REQ-TOOL-0012: search_project_files tool
class_name SearchProjectFilesTool
# REQ-TOOL-0012: search_project_files tool
extends AITool

func _init() -> void:
	super._init("search_project_files", "Search for exact strings or regular expressions in project files to find line numbers.")

func get_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"query": {
				"type": "string",
				"description": "The exact string or regular expression to search for."
			},
			"path": {
				"type": "string",
				"description": "The res:// path to a specific file or a directory to search within."
			},
			"is_regex": {
				"type": "boolean",
				"description": "If true, treats the query as a regular expression."
			},
			"filter": {
				"type": "string",
				"description": "Optional glob pattern (e.g. '*.gd') to limit the files searched when path is a directory."
			}
		},
		"required": ["query", "path"]
	}

func execute(arguments: Dictionary) -> String:
	var query = arguments.get("query", "")
	var path = arguments.get("path", "res://")
	var is_regex = arguments.get("is_regex", false)
	var filter = arguments.get("filter", "")
	
	if not path.begins_with("res://"):
		path = "res://" + path
		
	var regex: RegEx = null
	if is_regex:
		regex = RegEx.new()
		var err = regex.compile(query)
		if err != OK:
			return "Error: Invalid regular expression."
			
	var results := []
	var max_results = 50
	
	if FileAccess.file_exists(path):
		_search_in_file(path, query, regex, results, max_results)
	elif DirAccess.dir_exists_absolute(path):
		_search_in_directory(path, filter, query, regex, results, max_results)
	else:
		return "Error: Path '%s' does not exist." % path
		
	if results.is_empty():
		return "No matches found for query: '%s'" % query
		
	var output = "Found %d matches:\n" % results.size()
	for res in results:
		output += "%s:%d: %s\n" % [res["file"], res["line"], res["content"].strip_edges()]
		
	if results.size() >= max_results:
		output += "\nWarning: Results truncated at %d matches." % max_results
		
	return output

func _search_in_directory(dir_path: String, filter: String, query: String, regex: RegEx, results: Array, max_results: int) -> void:
	if results.size() >= max_results:
		return
		
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
			
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
			
		var full_path = dir_path.path_join(file_name)
		if dir.current_is_dir():
			_search_in_directory(full_path, filter, query, regex, results, max_results)
		else:
			if filter.is_empty() or file_name.match(filter):
				# check if it's text-based
				var ext = file_name.get_extension().to_lower()
				if ext in ["gd", "tscn", "tres", "txt", "md", "json", "xml", "cfg", "gdshader", "shader"]:
					_search_in_file(full_path, query, regex, results, max_results)
					
		if results.size() >= max_results:
			break
			
		file_name = dir.get_next()

func _search_in_file(file_path: String, query: String, regex: RegEx, results: Array, max_results: int) -> void:
	if results.size() >= max_results:
		return
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return
		
	var line_number = 1
	while not file.eof_reached():
		var line = file.get_line()
		var match_found = false
		
		if regex:
			if regex.search(line):
				match_found = true
		else:
			if line.find(query) != -1:
				match_found = true
				
		if match_found:
			results.append({
				"file": file_path,
				"line": line_number,
				"content": line
			})
			if results.size() >= max_results:
				break
				
		line_number += 1
		
	file.close()
