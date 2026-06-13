extends AITool

func _init() -> void:
	super("read_webpage", "Read parts of a webpage. IMPORTANT: Because this consumes significant context, you MUST immediately produce a summary of the relevant information you found to retain it after context compression. Use start_line and end_line for large pages.")

func get_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"url": {
				"type": "string",
				"description": "The full URL of the webpage to read."
			},
			"start_line": {
				"type": "integer",
				"description": "Optional. The 1-based starting line number to read."
			},
			"end_line": {
				"type": "integer",
				"description": "Optional. The inclusive ending line number to read."
			}
		},
		"required": ["url"]
	}

func execute(arguments: Dictionary) -> Variant:
	var url: String = arguments.get("url", "")
	var start_line: int = arguments.get("start_line", 1)
	var end_line: int = arguments.get("end_line", -1)
	
	if url.is_empty():
		return "Error: url cannot be empty."

	if context_node == null:
		return "Error: context_node is null."

	# 1. Parse URL to get host and path
	var host = ""
	var path = "/"
	var scheme = "https://"
	if url.begins_with("http://"):
		scheme = "http://"
	elif not url.begins_with("https://"):
		# Default to https if missing
		url = "https://" + url
		
	var without_scheme = url.substr(scheme.length())
	var slash_idx = without_scheme.find("/")
	if slash_idx != -1:
		host = without_scheme.substr(0, slash_idx)
		path = without_scheme.substr(slash_idx)
	else:
		host = without_scheme

	# 2. Check robots.txt
	var robots_url = scheme + host + "/robots.txt"
	var allowed = await _check_robots_txt(robots_url, path)
	if not allowed:
		return "Error: Access to this URL is restricted by the site's robots.txt"

	# 3. Fetch URL
	var http_request = HTTPRequest.new()
	context_node.add_child(http_request)
	var headers = ["User-Agent: GodotAIAssistant/1.0"]
	var err = http_request.request(url, headers)
	
	if err != OK:
		http_request.queue_free()
		return "Error: failed to initiate HTTP request to " + url
		
	var response = await http_request.request_completed
	var result = response[0]
	var response_code = response[1]
	var body_bytes = response[3]
	http_request.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return "Error: HTTP request failed with code " + str(response_code)
		
	var html = body_bytes.get_string_from_utf8()
	
	# 4. Strip HTML
	var text = _strip_html(html)
	
	# 5. Pagination
	var lines = text.split("\n")
	var total_lines = lines.size()
	
	var actual_start = clampi(start_line - 1, 0, total_lines - 1)
	var actual_end = total_lines - 1
	if end_line != -1:
		actual_end = clampi(end_line - 1, actual_start, total_lines - 1)
	elif total_lines > 150 and start_line == 1:
		actual_end = 149
		
	var chunk = ""
	for i in range(actual_start, actual_end + 1):
		chunk += str(i + 1) + ": " + lines[i] + "\n"
		
	if actual_end < total_lines - 1:
		chunk += "\n... (Content truncated. Total lines: " + str(total_lines) + ". Use start_line and end_line to read more.)"
		
	return chunk

func _check_robots_txt(robots_url: String, target_path: String) -> bool:
	var http_request = HTTPRequest.new()
	context_node.add_child(http_request)
	var headers = ["User-Agent: GodotAIAssistant/1.0"]
	var err = http_request.request(robots_url, headers)
	if err != OK:
		http_request.queue_free()
		return true # Default to allow
		
	var response = await http_request.request_completed
	var result = response[0]
	var response_code = response[1]
	var body_bytes = response[3]
	http_request.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return true
		
	var content = body_bytes.get_string_from_utf8()
	var lines = content.split("\n")
	
	var in_relevant_agent = false
	var is_allowed = true
	
	for line in lines:
		var l = line.strip_edges()
		if l.begins_with("#") or l.is_empty():
			continue
			
		var lower_l = l.to_lower()
		if lower_l.begins_with("user-agent:"):
			var agent = l.substr(11).strip_edges().to_lower()
			in_relevant_agent = (agent == "*" or agent == "godotaiassistant")
		elif in_relevant_agent and lower_l.begins_with("disallow:"):
			var disallow_path = l.substr(9).strip_edges()
			if disallow_path.is_empty():
				continue
			if target_path.begins_with(disallow_path) or disallow_path == "/":
				is_allowed = false
		elif in_relevant_agent and lower_l.begins_with("allow:"):
			var allow_path = l.substr(6).strip_edges()
			if target_path.begins_with(allow_path):
				is_allowed = true
				
	return is_allowed

func _strip_html(html: String) -> String:
	var text = html
	
	var start_body = text.find("<body")
	if start_body != -1:
		text = text.substr(start_body)
	var end_body = text.find("</body>")
	if end_body != -1:
		text = text.substr(0, end_body)

	var regex = RegEx.new()
	regex.compile("<script[^>]*>.*?</script>")
	text = regex.sub(text, " ", true)
	
	regex.compile("<style[^>]*>.*?</style>")
	text = regex.sub(text, " ", true)

	regex.compile("<[^>]*>")
	var stripped = regex.sub(text, " ", true)
	
	stripped = stripped.replace("&quot;", "\"")
	stripped = stripped.replace("&amp;", "&")
	stripped = stripped.replace("&lt;", "<")
	stripped = stripped.replace("&gt;", ">")
	stripped = stripped.replace("&#39;", "'")
	stripped = stripped.replace("&nbsp;", " ")
	
	var space_regex = RegEx.new()
	space_regex.compile("[ \\t]{2,}")
	stripped = space_regex.sub(stripped, " ", true)
	
	var nl_regex = RegEx.new()
	nl_regex.compile("\\n\\s*\\n")
	stripped = nl_regex.sub(stripped, "\n", true)
	
	return stripped.strip_edges()
