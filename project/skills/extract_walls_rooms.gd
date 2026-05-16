class_name ExtractWallsRoomsSkillOld
extends Node

# Skill to extract walls and rooms information from the scene
static func execute(node: Node) -> String:
	var result := ""
	
	# Get the blueprint reference node
	var house_building: Node3D = node.get_node("../../BlueprintReference")
	if house_building == null:
		return "Error: BlueprintReference node not found"
	
	# Extract walls data
	var walls_node: Node3D = house_building.get_node("Walls")
	if walls_node != null:
		result += "Wall Data Extracted:\n"
		result += "====================\n"
		
		for wall in walls_node.get_children():
			if wall is MeshInstance3D:
				var pos: Vector3 = wall.position
				var size: Vector3 = wall.mesh.size
				result += "Wall: " + wall.name + "\n"
				result += "  Position: " + str(pos) + "\n"
				result += "  Size: " + str(size) + "\n"
				result += "\n"
	else:
		result += "No Walls node found\n\n"
	
	# Extract rooms data
	var rooms_node: Node3D = house_building.get_node("Rooms")
	if rooms_node != null:
		result += "Room Data Extracted:\n"
		result += "====================\n"
		
		for room in rooms_node.get_children():
			if room is MeshInstance3D:
				var pos: Vector3 = room.position
				var size: Vector3 = room.mesh.size
				result += "Room: " + room.name + "\n"
				result += "  Position: " + str(pos) + "\n"
				result += "  Size: " + str(size) + "\n"
				result += "\n"
	else:
		result += "No Rooms node found\n\n"
	
	# Extract additional information if available
	var room_info_node: Node3D = house_building.get_node("RoomInfo")
	if room_info_node != null:
		result += "Additional Room Info:\n"
		result += "=====================\n"
		
		for info in room_info_node.get_children():
			if info is Node3D and info.name.begins_with("Room"):
				var pos: Vector3 = info.position
				var name: String = info.name
				result += "Room Info: " + name + "\n"
				result += "  Position: " + str(pos) + "\n"
				result += "\n"
	
	return result

# Additional utility functions for more detailed extraction
static func get_walls_data(node: Node) -> Array:
	var walls_data := []
	
	var house_building: Node3D = node.get_node("../../BlueprintReference")
	if house_building == null:
		return walls_data
	
	var walls_node: Node3D = house_building.get_node("Walls")
	if walls_node != null:
		for wall in walls_node.get_children():
			if wall is MeshInstance3D:
				var wall_data := {
					"name": wall.name,
					"position": wall.position,
					"size": wall.mesh.size
				}
				walls_data.append(wall_data)
	
	return walls_data

static func get_rooms_data(node: Node) -> Array:
	var rooms_data := []
	
	var house_building: Node3D = node.get_node("../../BlueprintReference")
	if house_building == null:
		return rooms_data
	
	var rooms_node: Node3D = house_building.get_node("Rooms")
	if rooms_node != null:
		for room in rooms_node.get_children():
			if room is MeshInstance3D:
				var room_data := {
					"name": room.name,
					"position": room.position,
					"size": room.mesh.size
				}
				rooms_data.append(room_data)
	
	return rooms_data
