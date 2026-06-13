extends AITool

func _init() -> void:
	super("search_web", "Search the internet for information, documentation, and tutorials to assist with general coding or Godot specific tasks that aren't available locally.")

func get_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"query": {
				"type": "string",
				"description": "The search string to query the web."
			}
		},
		"required": ["query"]
	}

func execute(arguments: Dictionary) -> Variant:
	var query: String = arguments.get("query", "")
	if query.is_empty():
		return "Error: query cannot be empty."

	if context_node == null:
		return "Error: context_node is null."

	var http_request = HTTPRequest.new()
	context_node.add_child(http_request)
	
	var headers = ["User-Agent: GodotAIAssistant/1.0", "Content-Type: application/x-www-form-urlencoded"]
	var url = "https://lite.duckduckgo.com/lite/"
	var body = "q=" + query.uri_encode()
	
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http_request.queue_free()
		return "Error: failed to initiate HTTP request."
	
	var response = await http_request.request_completed
	var result = response[0]
	var response_code = response[1]
	var body_bytes = response[3]
	
	http_request.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS:
		return "Error: HTTP request failed with result code " + str(result)
		
	if response_code != 200:
		return "Error: HTTP response code " + str(response_code)
		
	var html = body_bytes.get_string_from_utf8()
	
	# Crude HTML stripping to return readable text to the AI
	var text = _strip_html(html)
	
	# Limit length to prevent token overflow
	if text.length() > 4000:
		text = text.substr(0, 4000) + "... (truncated)"
		
	return text

func _strip_html(html: String) -> String:
	var text = html
	
	# Try to extract the body content
	var start_body = text.find("<body")
	if start_body != -1:
		text = text.substr(start_body)
	var end_body = text.find("</body>")
	if end_body != -1:
		text = text.substr(0, end_body)

	# Remove scripts and styles completely
	var regex = RegEx.new()
	regex.compile("<script[^>]*>.*?</script>")
	text = regex.sub(text, " ", true)
	
	regex.compile("<style[^>]*>.*?</style>")
	text = regex.sub(text, " ", true)

	# Strip tags
	regex.compile("<[^>]*>")
	var stripped = regex.sub(text, " ", true)
	
	# Replace common HTML entities
	stripped = stripped.replace("&quot;", "\"")
	stripped = stripped.replace("&amp;", "&")
	stripped = stripped.replace("&lt;", "<")
	stripped = stripped.replace("&gt;", ">")
	stripped = stripped.replace("&#39;", "'")
	stripped = stripped.replace("&nbsp;", " ")
	
	# Collapse multiple whitespace
	var space_regex = RegEx.new()
	space_regex.compile("\\s{2,}")
	stripped = space_regex.sub(stripped, "\n", true)
	
	return stripped.strip_edges()
