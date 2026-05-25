@tool
extends "res://addons/ai_assistant/skills/ai_skill_node.gd"
class_name CreateWallSkill

## CreateWallSkill - A specialized skill for creating walls with openings.

func _init() -> void:
	description = "Creates a 3D wall with configurable openings (doors/windows)."
	definition = """
		This skill creates axis-aligned walls (X or Z) at Y=0.
		Walls are 2.5m high and use CSG for subtraction of openings.
		
		Openings:
		- doors: default 2.1m high, custom width. Default starts at Y=0.
		- windows: default 1.2m high, custom width. Default starts at Y=0.8m.
		- (Optional) height: Custom height for the opening.
		- (Optional) y_offset: Custom vertical distance from the floor.
		
		CRITICAL RULES FOR AI:
		1. start_position is the END/CORNER of the wall, NOT the center of a room! Do not use room centroids as start_position.
		2. direction determines which axis the wall runs along. Ensure 'length' matches the dimension of the wall along that axis (do not swap width/depth).
		3. To perfectly center an opening on the wall, calculate: offset = (wall_length - opening_width) / 2.0
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
						"name": { "type": "string", "description": "The name of the wall node" },
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
									"width": { "type": "number" },
									"height": { "type": "number", "description": "Optional custom height" },
									"y_offset": { "type": "number", "description": "Optional vertical offset from floor" }
								}
							}
						}
					},
					"required": ["name", "start_position", "direction", "length", "thickness"]
				}
			}
		}
	]

func create_wall(arguments: Dictionary) -> String:
	var wall_name: String = arguments.get("name", "Wall_Generated")
	var start_pos_arr: Array = arguments.get("start_position", [0, 0, 0])
	var start_pos := Vector3(start_pos_arr[0], start_pos_arr[1], start_pos_arr[2])
	var direction: String = arguments.get("direction", "+X")
	var length: float = arguments.get("length", 1.0)
	var thickness: float = arguments.get("thickness", 0.2)
	var openings: Array = arguments.get("openings", [])
	
	var root := CSGCombiner3D.new()
	root.name = wall_name
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
			var height: float = op.get("height", 2.1)
			var y_offset: float = op.get("y_offset", 0.0)
			hole.size = Vector3(width, height, thickness + 0.1)
			hole.position = Vector3(offset + width/2.0, y_offset + height/2.0, 0)
		else: # window
			var height: float = op.get("height", 1.2)
			var y_offset: float = op.get("y_offset", 0.8)
			hole.size = Vector3(width, height, thickness + 0.1)
			hole.position = Vector3(offset + width/2.0, y_offset + height/2.0, 0)
			
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
