## ExploreNodeHierarchyTool - Tool for exploring and inspecting the scene tree.
##
## Allows the AI to navigate the hierarchy and check node properties.

class_name ExploreNodeHierarchyTool
extends AITool


func _init() -> void:
	super("explore_node_hierarchy", "Explore and inspect the Godot scene tree relative to the assistant node.")


func get_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"command": {
				"type": "string",
				"enum": ["list_children", "list_ancestors", "get_node_info", "get_tree_structure", "inspect_property"],
				"description": "The exploration command to execute."
			},
			"path": {
				"type": "string",
				"description": "Relative path to the node from the assistant (default is '.' for the assistant itself)."
			},
			"property": {
				"type": "string",
				"description": "The property to inspect (can use dot notation for resources, e.g. 'mesh:size'). Only used with 'inspect_property' command."
			},
			"depth": {
				"type": "integer",
				"description": "Max depth for get_tree_structure (default 2).",
				"default": 2
			}
		},
		"required": ["command"]
	}


func execute(arguments: Dictionary) -> String:
	if not context_node:
		return "Error: No context node provided to the tool."

	var command: String = arguments.get("command", "")
	var relative_path: String = arguments.get("path", ".")
	var target_node: Node = context_node.get_node_or_null(relative_path)

	if not target_node:
		return "Error: Node not found at path: " + relative_path

	match command:
		"list_children":
			return JSON.stringify(_list_children(target_node))
		"list_ancestors":
			return JSON.stringify(_list_ancestors(target_node))
		"get_node_info":
			return JSON.stringify(_get_node_info(target_node))
		"get_tree_structure":
			var depth: int = arguments.get("depth", 2)
			return JSON.stringify(_get_tree_structure(target_node, depth))
		"inspect_property":
			var property_path: String = arguments.get("property", "")
			if property_path.is_empty():
				return "Error: No property specified for inspect_property."
			return JSON.stringify(_inspect_property(target_node, property_path))
		_:
			return "Error: Unknown command: " + command


func _list_children(node: Node) -> Dictionary:
	var children: Array = []
	for child in node.get_children():
		children.append({
			"name": child.name,
			"class": child.get_class(),
			"path": node.get_path_to(child)
		})
	return {
		"node": node.name,
		"children": children
	}


func _list_ancestors(node: Node) -> Dictionary:
	var ancestors: Array = []
	var current: Node = node.get_parent()
	while current:
		ancestors.append({
			"name": current.name,
			"class": current.get_class(),
			"path": node.get_path_to(current)
		})
		current = current.get_parent()
	return {
		"node": node.name,
		"ancestors": ancestors
	}


func _get_node_info(node: Node) -> Dictionary:
	var info: Dictionary = {
		"name": node.name,
		"class": node.get_class(),
		"properties": {}
	}
	
	var script = node.get_script()
	if script:
		info["script"] = script.resource_path

	for prop in node.get_property_list():
		# Filter for relevant properties (usage & PROPERTY_USAGE_EDITOR)
		if prop.usage & PROPERTY_USAGE_EDITOR or prop.usage & PROPERTY_USAGE_STORAGE:
			var p_name: String = prop.name
			# Skip internal properties and very common boilerplate
			if p_name.begins_with("_") or p_name in ["script", "multiplayer", "process_mode", "process_priority", "process_thread_group", "process_thread_group_order", "process_messages_display_priority", "editor_description"]:
				continue
				
			info.properties[p_name] = _get_value_summary(node.get(p_name))

	return info


func _inspect_property(node: Node, property_path: String) -> Dictionary:
	var parts = property_path.split(":", true)
	var current: Variant = node
	
	for i in range(parts.size()):
		var part = parts[i]
		if current is Object:
			current = current.get(part)
		else:
			return {"error": "Property path broke at '%s' because parent is not an object." % part}
	
	var result: Dictionary = {
		"property": property_path,
		"value": _get_value_summary(current)
	}
	
	if current is Object and current != null:
		result["class"] = current.get_class()
		result["sub_properties"] = {}
		for prop in current.get_property_list():
			if prop.usage & PROPERTY_USAGE_EDITOR or prop.usage & PROPERTY_USAGE_STORAGE:
				var p_name: String = prop.name
				if p_name.begins_with("_") or p_name in ["script", "resource_path", "resource_name", "resource_local_to_scene"]:
					continue
				result.sub_properties[p_name] = _get_value_summary(current.get(p_name))
				
	return result


func _get_value_summary(value: Variant) -> Variant:
	if value is Object:
		if value == null:
			return "null"
		else:
			var summary = "<" + value.get_class() + ">"
			if value is Resource and not value.resource_path.is_empty():
				summary += " (" + value.resource_path + ")"
			return summary
	return value


func _get_tree_structure(node: Node, max_depth: int, current_depth: int = 0) -> Dictionary:
	var info: Dictionary = {
		"name": node.name,
		"class": node.get_class()
	}
	
	if current_depth < max_depth:
		var children: Array = []
		for child in node.get_children():
			children.append(_get_tree_structure(child, max_depth, current_depth + 1))
		if not children.is_empty():
			info["children"] = children
			
	return info
