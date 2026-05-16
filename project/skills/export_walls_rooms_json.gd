class_name ExportWallsRoomsJSONSkill
extends Node

# Skill to export walls and rooms data to JSON format
static func execute(node: Node) -> String:
	var result := ""
	
	# Get the blueprint reference node
	var house_building: Node3D = node.get_node("../../BlueprintReference")
	if house_building == null:
		return "Error: BlueprintReference node not found"
	
	# Extract all data
	var data := {
		"walls": [],
		"rooms": [],
		"metadata": {
			"exported_at": Time.get_datetime_string_from_system(),
			"scene": node.get_scene_file_path()
		}
	}
	
	# Get walls
	var walls_node: Node3D = house_building.get_node("Walls")
	if walls_node != null:
		for wall in walls_node.get_children():
			if wall is MeshInstance3D:
				var wall_data := {
					"name": wall.name,
					"position": {
						"x": wall.position.x,
						"y": wall.position.y,
						"z": wall.position.z
					},
					"size": {
						"x": wall.mesh.size.x,
						"y": wall.mesh.size.y,
						"z": wall.mesh.size.z
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
	var rooms_node: Node3D = house_building.get_node("Rooms")
	if rooms_node != null:
		for room in rooms_node.get_children():
			if room is MeshInstance3D:
				var room_data := {
					"name": room.name,
					"position": {
						"x": room.position.x,
						"y": room.position.y,
						"z": room.position.z
					},
					"size": {
						"x": room.mesh.size.x,
						"y": room.mesh.size.y,
						"z": room.mesh.size.z
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
	
	# Convert to JSON string
	var json_string := JSON.stringify(data, "  ")
	
	# Save to file (in a real implementation, you might want to save to a specific location)
	result += "Exported Data:\n"
	result += "==============\n"
	result += json_string
	result += "\n\n"
	result += "[color=green]Data exported successfully to JSON format[/color]"
	
	return result

# Utility function to get the JSON data as a Dictionary
static func get_json_data(node: Node) -> String:
	var house_building: Node3D = node.get_node("../../BlueprintReference")
	if house_building == null:
		return ""
	
	# Extract all data
	var data := {
		"walls": [],
		"rooms": [],
		"metadata": {
			"exported_at": Time.get_datetime_string_from_system(),
			"scene": node.get_scene_file_path()
		}
	}
	
	# Get walls
	var walls_node: Node3D = house_building.get_node("Walls")
	if walls_node != null:
		for wall in walls_node.get_children():
			if wall is MeshInstance3D:
				var wall_data := {
					"name": wall.name,
					"position": {
						"x": wall.position.x,
						"y": wall.position.y,
						"z": wall.position.z
					},
					"size": {
						"x": wall.mesh.size.x,
						"y": wall.mesh.size.y,
						"z": wall.mesh.size.z
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
	var rooms_node: Node3D = house_building.get_node("Rooms")
	if rooms_node != null:
		for room in rooms_node.get_children():
			if room is MeshInstance3D:
				var room_data := {
					"name": room.name,
					"position": {
						"x": room.position.x,
						"y": room.position.y,
						"z": room.position.z
					},
					"size": {
						"x": room.mesh.size.x,
						"y": room.mesh.size.y,
						"z": room.mesh.size.z
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
	
	# Convert to JSON string
	return JSON.stringify(data, "  ")

# Utility function to save the JSON data to a file
static func save_json_file(node: Node, file_path: String) -> bool:
	var json_string := get_json_data(node)
	if json_string == "":
		return false
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(json_string)
		file.close()
		return true
	else:
		return false
