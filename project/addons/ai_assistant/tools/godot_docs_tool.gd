## GodotDocsTool - Allows the AI to explore Godot engine documentation.

class_name GodotDocsTool
extends AITool


const AISettings = preload("res://addons/ai_assistant/settings/ai_settings.gd")


func _init() -> void:
	super._init("explore_godot_docs", "List or search Godot classes, methods, and properties. Retrieve detailed documentation including descriptions from the engine or source code.")


func get_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"command": {
				"type": "string",
				"enum": ["list_classes", "search", "get_class_doc"],
				"description": "The command to execute."
			},
			"query": {
				"type": "string",
				"description": "The search keyword or class name."
			}
		},
		"required": ["command"]
	}


func execute(arguments: Dictionary) -> String:
	var command = arguments.get("command", "")
	var query = arguments.get("query", "")

	match command:
		"list_classes":
			return _list_classes(query)
		"search":
			return _search(query)
		"get_class_doc":
			return _get_class_doc(query)
		_:
			return "Error: Unknown command " + command


func _list_classes(filter: String) -> String:
	var classes = ClassDB.get_class_list()
	classes.sort()
	
	if not filter.is_empty():
		var filtered = []
		for c in classes:
			if filter.to_lower() in c.to_lower():
				filtered.append(c)
		classes = filtered
	
	if classes.size() > 50:
		return "Found %d classes. Here are the first 50:\n" % classes.size() + ", ".join(classes.slice(0, 50))
	
	return "Classes: " + ", ".join(classes)


func _search(query: String) -> String:
	if query.is_empty():
		return "Error: Search query is empty."
	
	var results = []
	var classes = ClassDB.get_class_list()
	
	for c in classes:
		if query.to_lower() in c.to_lower():
			results.append("Class: " + c)
		
		# Check methods
		var methods = ClassDB.class_get_method_list(c, true)
		for m in methods:
			if query.to_lower() in m.name.to_lower():
				results.append("Method: %s.%s" % [c, m.name])
		
		# Check properties
		var props = ClassDB.class_get_property_list(c, true)
		for p in props:
			if query.to_lower() in p.name.to_lower():
				results.append("Property: %s.%s" % [c, p.name])

		if results.size() > 20:
			break
			
	if results.is_empty():
		return "Error: No results found for '%s'." % query
	
	return "Search results for '%s':\n" % query + "\n".join(results)


func _get_class_doc(p_class_name: String) -> String:
	if not ClassDB.class_exists(p_class_name):
		return "Error: Class '%s' not found." % p_class_name
	
	var doc_info = _find_doc_in_source(p_class_name)
	
	var doc = "Class: %s\n" % p_class_name
	doc += "Inherits: %s\n\n" % ClassDB.get_parent_class(p_class_name)
	
	if not doc_info.is_empty():
		doc += "Description: %s\n\n" % doc_info.get("brief_description", "No brief description found.")
		if not doc_info.get("description", "").is_empty():
			doc += "Detailed Description:\n%s\n\n" % doc_info["description"]
	else:
		doc += "Description: (Detailed description not available in engine. Configure 'ai/tools/godot_source_path' to enable full documentation parsing from Godot source.)\n\n"
	
	doc += "Properties:\n"
	var props = ClassDB.class_get_property_list(p_class_name, true)
	for p in props:
		if p.usage & PROPERTY_USAGE_EDITOR:
			var p_doc = ""
			if not doc_info.is_empty() and doc_info.has("members") and doc_info.members.has(p.name):
				p_doc = " - " + doc_info.members[p.name]
			doc += "- %s (%s)%s\n" % [p.name, _get_type_name(p.type), p_doc]
	
	doc += "\nMethods:\n"
	var methods = ClassDB.class_get_method_list(p_class_name, true)
	for m in methods:
		if not m.name.begins_with("_"):
			var m_doc = ""
			if not doc_info.is_empty() and doc_info.has("methods") and doc_info.methods.has(m.name):
				m_doc = "\n    " + doc_info.methods[m.name]
			doc += "- %s(%s)%s\n" % [m.name, _get_args_string(m.args), m_doc]
			
	return doc


func _find_doc_in_source(p_class_name: String) -> Dictionary:
	var source_path = AISettings.get_string(AISettings.TOOLS, "godot_source_path")
	if source_path.is_empty():
		return {}
	
	var paths_to_check = [
		source_path.path_join("doc/classes").path_join(p_class_name + ".xml")
	]
	
	# Also check modules
	var modules_dir = source_path.path_join("modules")
	var dir = DirAccess.open(modules_dir)
	if dir:
		dir.list_dir_begin()
		var module = dir.get_next()
		while module != "":
			if dir.current_is_dir() and not module.begins_with("."):
				paths_to_check.append(modules_dir.path_join(module).path_join("doc_classes").path_join(p_class_name + ".xml"))
			module = dir.get_next()
			
	for path in paths_to_check:
		if FileAccess.file_exists(path):
			return _parse_doc_xml(path)
			
	return {}


func _parse_doc_xml(path: String) -> Dictionary:
	var parser = XMLParser.new()
	var err = parser.open(path)
	if err != OK:
		return {}
	
	var result = {
		"brief_description": "",
		"description": "",
		"methods": {},
		"members": {},
		"constants": {},
		"signals": {}
	}
	
	var current_element = ""
	var current_item_name = ""
	
	while parser.read() == OK:
		var type = parser.get_node_type()
		
		if type == XMLParser.NODE_ELEMENT:
			var node_name = parser.get_node_name()
			current_element = node_name
			
			if node_name == "method" or node_name == "member" or node_name == "constant" or node_name == "signal":
				for i in range(parser.get_attribute_count()):
					if parser.get_attribute_name(i) == "name":
						current_item_name = parser.get_attribute_value(i)
						break
						
		elif type == XMLParser.NODE_TEXT or type == XMLParser.NODE_CDATA:
			var text = parser.get_node_data().strip_edges()
			if text.is_empty():
				continue
				
			match current_element:
				"brief_description":
					result.brief_description = text
				"description":
					if current_item_name.is_empty():
						result.description = text
					elif result.methods.has(current_item_name): # This is simplified
						pass 
				"method":
					# XML structure is <method name="..."><description>...</description></method>
					# We need to handle nested elements. This simple state machine is a bit too simple.
					pass
		
		elif type == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() in ["method", "member", "constant", "signal"]:
				current_item_name = ""
				current_element = ""

	# Re-run with a better approach for descriptions of methods/members
	# Actually, XMLParser is a bit low-level for complex nesting without a stack.
	# Let's do a slightly more robust pass for members and methods.
	return _parse_doc_xml_robust(path)


func _parse_doc_xml_robust(path: String) -> Dictionary:
	var parser = XMLParser.new()
	parser.open(path)
	
	var result = {
		"brief_description": "",
		"description": "",
		"methods": {},
		"members": {},
	}
	
	var section = "" # brief_description, description, methods, members
	var current_item = ""
	
	while parser.read() == OK:
		var type = parser.get_node_type()
		var node_name = ""
		if type == XMLParser.NODE_ELEMENT or type == XMLParser.NODE_ELEMENT_END:
			node_name = parser.get_node_name()
		
		if type == XMLParser.NODE_ELEMENT:
			if node_name == "brief_description":
				section = "brief"
			elif node_name == "description" and section != "method" and section != "member":
				section = "desc"
			elif node_name == "methods":
				section = "methods_list"
			elif node_name == "method":
				section = "method"
				current_item = parser.get_attribute_value(0) # name is usually first
				for i in range(parser.get_attribute_count()):
					if parser.get_attribute_name(i) == "name":
						current_item = parser.get_attribute_value(i)
			elif node_name == "members":
				section = "members_list"
			elif node_name == "member":
				section = "member"
				current_item = parser.get_attribute_value(0)
				for i in range(parser.get_attribute_count()):
					if parser.get_attribute_name(i) == "name":
						current_item = parser.get_attribute_value(i)
			elif node_name == "description" and (section == "method" or section == "member"):
				section = section + "_desc"
				
		elif type == XMLParser.NODE_TEXT or type == XMLParser.NODE_CDATA:
			var text = parser.get_node_data().strip_edges()
			if text.is_empty(): continue
			
			if section == "brief":
				result.brief_description += text
			elif section == "desc":
				result.description += text
			elif section == "method_desc" and not current_item.is_empty():
				if not result.methods.has(current_item):
					result.methods[current_item] = ""
				result.methods[current_item] += text
			elif section == "member" and not current_item.is_empty():
				if not result.members.has(current_item):
					result.members[current_item] = ""
				result.members[current_item] += text
			elif section == "member_desc" and not current_item.is_empty():
				if not result.members.has(current_item):
					result.members[current_item] = ""
				result.members[current_item] += text
				
		elif type == XMLParser.NODE_ELEMENT_END:
			if node_name == "method":
				section = "methods_list"
				current_item = ""
			elif node_name == "member":
				section = "members_list"
				current_item = ""
			elif node_name == "description":
				if section == "method_desc": section = "method"
				elif section == "member_desc": section = "member"
				elif section == "desc": section = ""
			elif node_name == "brief_description":
				section = ""
				
	return result


func _get_type_name(type_id: int) -> String:
	match type_id:
		TYPE_NIL: return "Variant"
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_COLOR: return "Color"
		TYPE_OBJECT: return "Object"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_ARRAY: return "Array"
		_: return "Variant"


func _get_args_string(args: Array) -> String:
	var arg_names = []
	for arg in args:
		arg_names.append(arg.name)
	return ", ".join(arg_names)
