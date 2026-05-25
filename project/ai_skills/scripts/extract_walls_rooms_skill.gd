@tool
class_name ExtractWallsRoomsSkill
extends "res://addons/ai_assistant/skills/ai_skill_node.gd"

# Helper function to normalize Y-axis rotation to nearest 90-degree increment
static func _normalize_y_rotation(rotation: Vector3) -> float:
	var y_rot = rotation.y
	# Round to nearest multiple of 90 degrees
	var normalized = round(y_rot / 90.0) * 90.0
	return normalized

# Helper function to get the base size of a wall node, supporting standard meshes and CSG shapes
static func _get_wall_size(wall: Node3D) -> Vector3:
	if wall is MeshInstance3D:
		return wall.mesh.size if wall.mesh != null else Vector3.ZERO
	elif wall is CSGBox3D:
		return wall.size
	elif wall is CSGCombiner3D or wall.has_method("get_children"):
		for child in wall.get_children():
			if child is CSGBox3D:
				return child.size
			elif child is MeshInstance3D:
				return child.mesh.size if child.mesh != null else Vector3.ZERO
	return Vector3.ZERO

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
	
	# Get the parent node of Walls and Rooms dynamically
	var house_building: Node = get_tree().get_edited_scene_root()
	if house_building != null:
		var w = house_building.find_child("Walls", true, false)
		if w != null:
			house_building = w.get_parent()
	
	if house_building == null:
		return "Error: Scene root not found"
	
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
			if wall is Node3D:
				var pos = wall.position
				var size = _get_wall_size(wall)
				var rotation = wall.rotation_degrees
				
				# Normalize Y-axis rotation and handle 90-degree increments
				var normalized_y_rot = _normalize_y_rotation(rotation)
				var is_rotated_90 = int(abs(normalized_y_rot)) % 180 == 90
				
				# Swap X and Z dimensions for walls rotated by 90 or 270 degrees
				if is_rotated_90:
					size = Vector3(size.z, size.y, size.x)
				
				var length = size.x
				if is_rotated_90:
					length = size.z
				
				var end_pos = pos
				var dir_str = "Unknown"
				if abs(normalized_y_rot) < 1.0:
					end_pos = pos + Vector3(length, 0, 0)
					dir_str = "+X"
				elif abs(normalized_y_rot - 180.0) < 1.0 or abs(normalized_y_rot + 180.0) < 1.0:
					end_pos = pos + Vector3(-length, 0, 0)
					dir_str = "-X"
				elif abs(normalized_y_rot + 90.0) < 1.0:
					end_pos = pos + Vector3(0, 0, length)
					dir_str = "+Z"
				elif abs(normalized_y_rot - 90.0) < 1.0:
					end_pos = pos + Vector3(0, 0, -length)
					dir_str = "-Z"
				
				if format == "text":
					result += "Wall: " + wall.name + "\n"
					result += "  Direction: " + dir_str + "\n"
					result += "  Start Position: " + str(pos) + "\n"
					result += "  End Position: " + str(end_pos) + "\n"
					result += "  Length: " + str(length) + "\n"
					result += "  Bounding Size: " + str(size) + "\n"
					result += "  Rotation: " + str(rotation) + "\n"
					
					# Warn if rotation is not a multiple of 90 degrees
					if abs(normalized_y_rot - rotation.y) > 1.0:
						result += "  [color=orange]Warning: Non-90° Y rotation detected (" + str(rotation.y) + "°)\n[/color]"
					
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
				
				# Normalize Y-axis rotation and handle 90-degree increments
				var normalized_y_rot = _normalize_y_rotation(rotation)
				var is_rotated_90 = int(abs(normalized_y_rot)) % 180 == 90
				
				# Swap X and Z dimensions for rooms rotated by 90 or 270 degrees
				if is_rotated_90:
					size = Vector3(size.z, size.y, size.x)
				
				if format == "text":
					result += "Room: " + room.name + "\n"
					result += "  Centroid Position: " + str(pos) + "\n"
					result += "  Size: " + str(size) + "\n"
					result += "  Bounds X: [" + str(pos.x - size.x/2.0) + " to " + str(pos.x + size.x/2.0) + "]\n"
					result += "  Bounds Z: [" + str(pos.z - size.z/2.0) + " to " + str(pos.z + size.z/2.0) + "]\n"
					result += "  Rotation: " + str(rotation) + "\n"
					
					# Warn if rotation is not a multiple of 90 degrees
					if abs(normalized_y_rot - rotation.y) > 1.0:
						result += "  [color=orange]Warning: Non-90° Y rotation detected (" + str(rotation.y) + "°)\n[/color]"
					
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
	
	# Get the parent node of Walls and Rooms dynamically
	var house_building = get_tree().get_edited_scene_root()
	if house_building != null:
		var w = house_building.find_child("Walls", true, false)
		if w != null:
			house_building = w.get_parent()
	
	if house_building == null:
		return "Error: Scene root not found"
	
	result += "Data Validation Results:\n"
	result += "========================\n\n"
	
	var validation_errors = []
	var validation_warnings = []
	
	# Validate walls
	var walls_node = house_building.get_node("Walls")
	if walls_node != null:
		for wall in walls_node.get_children():
			if wall is Node3D:
				var size = _get_wall_size(wall)
				if size == Vector3.ZERO:
					validation_errors.append("Wall '" + wall.name + "' has no valid size or mesh/CSG box assigned")
				else:
					if size.x <= 0:
						validation_errors.append("Wall '" + wall.name + "' has invalid width (x)")
					if size.y <= 0:
						validation_errors.append("Wall '" + wall.name + "' has invalid height (y)")
					if size.z <= 0:
						validation_errors.append("Wall '" + wall.name + "' has invalid depth (z)")
				
				# Check for valid position
				if is_nan(wall.position.x) or is_nan(wall.position.y) or is_nan(wall.position.z):
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
				if is_nan(room.position.x) or is_nan(room.position.y) or is_nan(room.position.z):
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
	
	# Get the parent node of Walls and Rooms dynamically
	var house_building = get_tree().get_edited_scene_root()
	if house_building != null:
		var w = house_building.find_child("Walls", true, false)
		if w != null:
			house_building = w.get_parent()
	
	if house_building == null:
		return "Error: Scene root not found"
	
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
			if wall is Node3D:
				var wall_size = _get_wall_size(wall)
				var wall_rot = wall.rotation_degrees
				var norm_y = _normalize_y_rotation(wall_rot)
				if int(abs(norm_y)) % 180 == 90:
					wall_size = Vector3(wall_size.z, wall_size.y, wall_size.x)
				
				var wall_data = {
					"name": wall.name,
					"position": {
						"x": wall.position.x,
						"y": wall.position.y,
						"z": wall.position.z
					},
					"size": {
						"x": wall_size.x,
						"y": wall_size.y,
						"z": wall_size.z
					},
					"rotation": {
						"x": wall_rot.x,
						"y": wall_rot.y,
						"z": wall_rot.z
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
				var room_size = room.mesh.size if room.mesh != null else Vector3.ZERO
				var room_rot = room.rotation_degrees
				var norm_y = _normalize_y_rotation(room_rot)
				if int(abs(norm_y)) % 180 == 90:
					room_size = Vector3(room_size.z, room_size.y, room_size.x)
				
				var room_data = {
					"name": room.name,
					"position": {
						"x": room.position.x,
						"y": room.position.y,
						"z": room.position.z
					},
					"size": {
						"x": room_size.x,
						"y": room_size.y,
						"z": room_size.z
					},
					"rotation": {
						"x": room_rot.x,
						"y": room_rot.y,
						"z": room_rot.z
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
