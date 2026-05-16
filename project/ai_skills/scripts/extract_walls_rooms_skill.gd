@tool
class_name ExtractWallsRoomsSkill
extends "res://addons/ai_assistant/skills/ai_skill_node.gd"

func _init() -> void:
	description = "Extracts walls and rooms information from the scene including positions, sizes, and relationships."
	definition = """
		This skill extracts detailed information about walls and rooms in a 3D house blueprint scene.
		It can extract position, size, rotation data for each wall and room, as well as connection information.
		When called, it returns structured data about all walls and rooms in the BlueprintReference node.
	"""
	
	tools = [
		{
			"type": "function",
			"function": {
				"name": "extract_walls_rooms_data",
				"description": "Extracts position, size, and metadata for all walls and rooms in the scene",
				"parameters": {
					"type": "object",
					"properties": {
						"include_details": {
							"type": "boolean",
							"description": "Whether to include detailed metadata about each element"
						},
						"format": {
							"type": "string",
							"description": "Output format: 'text' or 'json'",
							"default": "text"
						}
					},
					"required": []
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "validate_walls_rooms",
				"description": "Validates the extracted walls and rooms data for consistency and correctness",
				"parameters": {
					"type": "object",
					"properties": {},
					"required": []
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "export_walls_rooms_json",
				"description": "Exports the walls and rooms data to JSON format",
				"parameters": {
					"type": "object",
					"properties": {
						"file_path": {
							"type": "string",
							"description": "Path where to save the JSON file"
						}
					},
					"required": []
				}
			}
		}
	]

func extract_walls_rooms_data(arguments: Dictionary) -> String:
	var include_details: bool = arguments.get("include_details", false)
	var format: String = arguments.get("format", "text")
	
	var result: String = ""
	
	# Get the blueprint reference node - using a more robust approach
	var house_building: Node = null
	
	# Try different possible paths to find BlueprintReference
	if has_node("../../../BlueprintReference"):
		house_building = get_node("../../../BlueprintReference")
	elif has_node("../../BlueprintReference"):
		house_building = get_node("../../BlueprintReference")
	elif has_node("../BlueprintReference"):
		house_building = get_node("../BlueprintReference")
	else:
		# Try to find it in the scene tree by name
		var root: Node = get_tree().root
		if root != null:
			var blueprint_ref: Node = root.find_child("BlueprintReference", true, false)
			if blueprint_ref != null:
				house_building = blueprint_ref
	
	if house_building == null:
		return "Error: BlueprintReference node not found"
	
	if format == "text":
		result += "Walls and Rooms Data Extracted:\n"
		result += "================================\n\n"
	
	# Extract walls data
	var walls_node = house_building.get_node("Walls")
	if walls_node != null:
		if format == "text":
			result += "Walls:\n"
			result += "------\n"
		
		for wall in walls_node.get_children():
			if wall is MeshInstance3D:
				var pos = wall.position
				var size = wall.mesh.size if wall.mesh != null else Vector3.ZERO
				var rotation = wall.rotation_degrees
				
				if format == "text":
					result += "Wall: " + wall.name + "\n"
					result += "  Position: " + str(pos) + "\n"
					result += "  Size: " + str(size) + "\n"
					result += "  Rotation: " + str(rotation) + "\n"
					
					if include_details and wall.has_meta("connected_to"):
						result += "  Connected to: " + str(wall.get_meta("connected_to")) + "\n"
					if include_details and wall.has_meta("wall_type"):
						result += "  Type: " + str(wall.get_meta("wall_type")) + "\n"
					
					result += "\n"
				else:
					# JSON format would be handled differently in a real implementation
					pass
	else:
		if format == "text":
			result += "No Walls node found\n\n"
	
	# Extract rooms data
	var rooms_node = house_building.get_node("Rooms")
	if rooms_node != null:
		if format == "text":
			result += "Rooms:\n"
			result += "------\n"
		
		for room in rooms_node.get_children():
			if room is MeshInstance3D:
				var pos = room.position
				var size = room.mesh.size if room.mesh != null else Vector3.ZERO
				var rotation = room.rotation_degrees
				
				if format == "text":
					result += "Room: " + room.name + "\n"
					result += "  Position: " + str(pos) + "\n"
					result += "  Size: " + str(size) + "\n"
					result += "  Rotation: " + str(rotation) + "\n"
					
					if include_details and room.has_meta("room_type"):
						result += "  Type: " + str(room.get_meta("room_type")) + "\n"
					if include_details and room.has_meta("room_id"):
						result += "  ID: " + str(room.get_meta("room_id")) + "\n"
					
					result += "\n"
				else:
					# JSON format would be handled differently in a real implementation
					pass
	else:
		if format == "text":
			result += "No Rooms node found\n\n"
	
	return result

func validate_walls_rooms(arguments: Dictionary) -> String:
	var result := ""
	
	# Get the blueprint reference node - using a more robust approach
	var house_building = null
	
	# Try different possible paths to find BlueprintReference
	if has_node("../../../BlueprintReference"):
		house_building = get_node("../../../BlueprintReference")
	elif has_node("../../BlueprintReference"):
		house_building = get_node("../../BlueprintReference")
	elif has_node("../BlueprintReference"):
		house_building = get_node("../BlueprintReference")
	else:
		# Try to find it in the scene tree by name
		var root = get_tree().root
		if root != null:
			var blueprint_ref = root.find_child("BlueprintReference", true, false)
			if blueprint_ref != null:
				house_building = blueprint_ref
	
	if house_building == null:
		return "Error: BlueprintReference node not found"
	
	result += "Data Validation Results:\n"
	result += "========================\n\n"
	
	var validation_errors = []
	var validation_warnings = []
	
	# Validate walls
	var walls_node = house_building.get_node("Walls")
	if walls_node != null:
		for wall in walls_node.get_children():
			if wall is MeshInstance3D:
				# Check if mesh exists
				if wall.mesh == null:
					validation_errors.append("Wall '" + wall.name + "' has no mesh assigned")
				
				# Check for valid size values (only check if mesh exists)
				if wall.mesh != null:
					if wall.mesh.size.x <= 0:
						validation_errors.append("Wall '" + wall.name + "' has invalid width (x)")
					if wall.mesh.size.y <= 0:
						validation_errors.append("Wall '" + wall.name + "' has invalid height (y)")
					if wall.mesh.size.z <= 0:
						validation_errors.append("Wall '" + wall.name + "' has invalid depth (z)")
				
				# Check for valid position
				if wall.position.x.is_nan() or wall.position.y.is_nan() or wall.position.z.is_nan():
					validation_errors.append("Wall '" + wall.name + "' has invalid position")
	
	# Validate rooms
	var rooms_node = house_building.get_node("Rooms")
	if rooms_node != null:
		for room in rooms_node.get_children():
			if room is MeshInstance3D:
				# Check if mesh exists
				if room.mesh == null:
					validation_errors.append("Room '" + room.name + "' has no mesh assigned")
				
				# Check for valid size values (only check if mesh exists)
				if room.mesh != null:
					if room.mesh.size.x <= 0:
						validation_errors.append("Room '" + room.name + "' has invalid width (x)")
					if room.mesh.size.y <= 0:
						validation_errors.append("Room '" + room.name + "' has invalid height (y)")
					if room.mesh.size.z <= 0:
						validation_errors.append("Room '" + room.name + "' has invalid depth (z)")
				
				# Check for valid position
				if room.position.x.is_nan() or room.position.y.is_nan() or room.position.z.is_nan():
					validation_errors.append("Room '" + room.name + "' has invalid position")
	
	# Display results
	if validation_errors.size() > 0:
		result += "[color=red]ERRORS FOUND:[/color]\n"
		for error in validation_errors:
			result += "  - " + error + "\n"
		result += "\n"
	else:
		result += "[color=green]No errors found[/color]\n\n"
	
	if validation_warnings.size() > 0:
		result += "[color=orange]WARNINGS:[/color]\n"
		for warning in validation_warnings:
			result += "  - " + warning + "\n"
		result += "\n"
	else:
		result += "[color=green]No warnings[/color]\n\n"
	
	# Overall summary
	if validation_errors.size() == 0:
		result += "[color=green]Overall Status: VALID[/color]"
	else:
		result += "[color=red]Overall Status: INVALID[/color]"
		
	return result

func export_walls_rooms_json(arguments: Dictionary) -> String:
	var file_path = arguments.get("file_path", "res://exported_walls_rooms.json")
	
	# Get the blueprint reference node - using a more robust approach
	var house_building = null
	
	# Try different possible paths to find BlueprintReference
	if has_node("../../../BlueprintReference"):
		house_building = get_node("../../../BlueprintReference")
	elif has_node("../../BlueprintReference"):
		house_building = get_node("../../BlueprintReference")
	elif has_node("../BlueprintReference"):
		house_building = get_node("../BlueprintReference")
	else:
		# Try to find it in the scene tree by name
		var root = get_tree().root
		if root != null:
			var blueprint_ref = root.find_child("BlueprintReference", true, false)
			if blueprint_ref != null:
				house_building = blueprint_ref
	
	if house_building == null:
		return "Error: BlueprintReference node not found"
	
	# Extract all data
	var data = {
		"walls": [],
		"rooms": [],
		"metadata": {
			"exported_at": Time.get_datetime_string_from_system(),
			"scene": get_scene_file_path()
		}
	}
	
	# Get walls
	var walls_node = house_building.get_node("Walls")
	if walls_node != null:
		for wall in walls_node.get_children():
			if wall is MeshInstance3D:
				var wall_data = {
					"name": wall.name,
					"position": {
						"x": wall.position.x,
						"y": wall.position.y,
						"z": wall.position.z
					},
					"size": {
						"x": wall.mesh.size.x if wall.mesh != null else 0.0,
						"y": wall.mesh.size.y if wall.mesh != null else 0.0,
						"z": wall.mesh.size.z if wall.mesh != null else 0.0
					},
					"rotation": {
						"x": wall.rotation_degrees.x,
						"y": wall.rotation_degrees.y,
						"z": wall.rotation_degrees.z
					}
				}
				
				# Add any metadata
				if wall.has_meta("connected_to"):
					wall_data["connected_to"] = wall.get_meta("connected_to")
				if wall.has_meta("wall_type"):
					wall_data["type"] = wall.get_meta("wall_type")
					
				data["walls"].append(wall_data)
	
	# Get rooms
	var rooms_node = house_building.get_node("Rooms")
	if rooms_node != null:
		for room in rooms_node.get_children():
			if room is MeshInstance3D:
				var room_data = {
					"name": room.name,
					"position": {
						"x": room.position.x,
						"y": room.position.y,
						"z": room.position.z
					},
					"size": {
						"x": room.mesh.size.x if room.mesh != null else 0.0,
						"y": room.mesh.size.y if room.mesh != null else 0.0,
						"z": room.mesh.size.z if room.mesh != null else 0.0
					},
					"rotation": {
						"x": room.rotation_degrees.x,
						"y": room.rotation_degrees.y,
						"z": room.rotation_degrees.z
					}
				}
				
				# Add any metadata
				if room.has_meta("room_type"):
					room_data["type"] = room.get_meta("room_type")
				if room.has_meta("room_id"):
					room_data["id"] = room.get_meta("room_id")
					
				data["rooms"].append(room_data)
	
	# Convert to JSON string and save
	var json_string = JSON.stringify(data, "  ")
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(json_string)
		file.close()
		return "Data successfully exported to " + file_path
	else:
		return "Error: Could not write to file " + file_path
