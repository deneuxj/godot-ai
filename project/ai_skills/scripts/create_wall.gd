@tool
extends "res://addons/ai_assistant/skills/ai_skill_node.gd"

## CreateWallSkill - A specialized skill for creating walls with openings.

func _init() -> void:
	description = "Creates a 3D wall with configurable openings (doors/windows)."
	definition = """
		This skill creates axis-aligned walls (X or Z) at Y=0.
		Walls are 2.5m high and use CSG for subtraction of openings.
		
		Openings:
		- doors: 2.1m high, 0.8m or 1.6m wide. Starts at Y=0.
		- windows: 1.2m high, custom width. Starts at Y=0.8m.
	"""
	
	tools = [
		{
			"type": "function",
			"function": {
				"name": "create_wall",
				"description": "Generates a 3D wall node in the scene.",
				"parameters": {
					"type": "object",
					"properties": {
						"start_position": { "type": "array", "items": { "type": "number" }, "description": "Start [x, y, z]" },
						"direction": { "type": "string", "enum": ["+X", "-X", "+Z", "-Z"] },
						"length": { "type": "number" },
						"thickness": { "type": "number" },
						"openings": {
							"type": "array",
							"items": {
								"type": "object",
								"properties": {
									"type": { "type": "string", "enum": ["door", "window"] },
									"offset": { "type": "number", "description": "Position relative to start" },
									"width": { "type": "number" }
								}
							}
						}
					},
					"required": ["start_position", "direction", "length", "thickness"]
				}
			}
		}
	]

func create_wall(arguments: Dictionary) -> String:
	var start_pos_arr: Array = arguments.get("start_position", [0, 0, 0])
	var start_pos := Vector3(start_pos_arr[0], start_pos_arr[1], start_pos_arr[2])
	var direction: String = arguments.get("direction", "+X")
	var length: float = arguments.get("length", 1.0)
	var thickness: float = arguments.get("thickness", 0.2)
	var openings: Array = arguments.get("openings", [])
	
	var root := CSGCombiner3D.new()
	root.name = "Wall_Generated"
	root.use_collision = true
	
	# Base Wall
	var wall_box := CSGBox3D.new()
	wall_box.size = Vector3(length, 2.5, thickness)
	# Center it so it starts at 0,0,0 in local space
	wall_box.position = Vector3(length/2.0, 1.25, 0)
	root.add_child(wall_box)
	
	# Openings
	for op in openings:
		var op_type: String = op.get("type", "door")
		var offset: float = op.get("offset", 0.0)
		var width: float = op.get("width", 0.8)
		
		var hole := CSGBox3D.new()
		hole.operation = CSGShape3D.OPERATION_SUBTRACTION
		
		if op_type == "door":
			hole.size = Vector3(width, 2.1, thickness + 0.1)
			hole.position = Vector3(offset + width/2.0, 1.05, 0)
		else: # window
			hole.size = Vector3(width, 1.2, thickness + 0.1)
			hole.position = Vector3(offset + width/2.0, 0.8 + 0.6, 0)
			
		root.add_child(hole)
	
	# Transform the root
	root.position = start_pos
	match direction:
		"+X": root.rotation_degrees.y = 0
		"-X": root.rotation_degrees.y = 180
		"+Z": root.rotation_degrees.y = -90
		"-Z": root.rotation_degrees.y = 90
		
	# Add to scene (under Generated node if it exists)
	var parent = get_parent().get_node_or_null("Generated")
	if not parent:
		parent = get_parent()
		
	parent.add_child(root)
	root.owner = get_tree().get_edited_scene_root()
	for child in root.get_children():
		child.owner = root.owner
		
	return "Successfully created wall at %s pointing %s" % [str(start_pos), direction]
