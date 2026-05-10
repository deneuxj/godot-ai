## BuildDynamicSceneTool - Allows the AI to generate and execute GDScript to build scene nodes.

class_name BuildDynamicSceneTool
extends AITool


func _init() -> void:
	super._init("build_dynamic_scene", "Execute a GDScript that defines a 'build() -> Node' function. Optionally add the node to the current tree or save it as a .tscn scene.")


func get_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"script_content": {
				"type": "string",
				"description": "The complete GDScript source code. It MUST define a function 'func build() -> Node:'."
			},
			"add_to_tree": {
				"type": "boolean",
				"description": "If true, the returned Node will be added as a child of the current AI node in the scene tree.",
				"default": true
			},
			"save_as_scene": {
				"type": "boolean",
				"description": "If true, the returned Node will be saved as a .tscn file. This only works in the Godot Editor.",
				"default": false
			},
			"scene_path": {
				"type": "string",
				"description": "The 'res://' path where the scene should be saved (e.g., 'res://generated/my_scene.tscn'). Required if save_as_scene is true."
			}
		},
		"required": ["script_content"]
	}


func execute(arguments: Dictionary) -> String:
	var script_content = arguments.get("script_content", "")
	var add_to_tree = arguments.get("add_to_tree", true)
	var save_as_scene = arguments.get("save_as_scene", false)
	var scene_path = arguments.get("scene_path", "")

	if script_content.is_empty():
		return "Error: script_content is empty."

	# 1. Compile and execute script
	var script = GDScript.new()
	script.source_code = script_content
	var reload_err = script.reload()
	if reload_err != OK:
		return "Error: Script compilation failed (Code: %d)." % reload_err

	var obj = script.new()
	
	if not obj.has_method("build"):
		if obj is Node:
			obj.free()
		return "Error: Script does not define a 'build()' function."

	var generated_node = obj.call("build")
	if obj is Node:
		obj.free()
	elif obj is RefCounted:
		pass
	else:
		obj.free()

	if not generated_node is Node:
		if generated_node != null and generated_node is Object:
			generated_node.free()
		return "Error: 'build()' did not return a valid Node."

	var result_msg = "Successfully executed build script."
	var node_handled = false

	# 2. Add to tree
	if add_to_tree:
		if context_node:
			context_node.add_child(generated_node)
			node_handled = true
			if Engine.is_editor_hint():
				generated_node.owner = context_node.get_tree().edited_scene_root
			result_msg += " Node added to the scene tree under '%s'." % context_node.name
		else:
			result_msg += " Warning: add_to_tree was true but no context_node was available."

	# 3. Save as scene
	if save_as_scene:
		if not Engine.is_editor_hint():
			result_msg += " Error: save_as_scene is only available in the Godot Editor."
		elif scene_path.is_empty():
			result_msg += " Error: save_as_scene is true but scene_path is empty."
		else:
			var packed_scene = PackedScene.new()
			var pack_err = packed_scene.pack(generated_node)
			if pack_err == OK:
				var save_err = ResourceSaver.save(packed_scene, scene_path)
				if save_err == OK:
					result_msg += " Node saved as scene at '%s'." % scene_path
				else:
					result_msg += " Error: Failed to save scene to '%s' (Code: %d)." % [scene_path, save_err]
			else:
				result_msg += " Error: Failed to pack node into a scene (Code: %d)." % pack_err

	if not node_handled and not generated_node.is_inside_tree():
		generated_node.free()

	return result_msg
