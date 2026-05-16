class_name ExtractDetailedWallsRoomsSkill
extends Node

# Advanced skill to extract detailed walls and rooms information with relationships
static func execute(node: Node) -> String:
	var result := ""
	
	# Get the blueprint reference node
	var house_building: Node3D = node.get_node("../../BlueprintReference")
	if house_building == null:
		return "Error: BlueprintReference node not found"
	
	# Extract walls data with more details
	var walls_node: Node3D = house_building.get_node("Walls")
	if walls_node != null:
		result += "Detailed Wall Data Extracted:\n"
		result += "==============================\n"
		
		for wall in walls_node.get_children():
			if wall is MeshInstance3D:
				var pos: Vector3 = wall.position
				var size: Vector3 = wall.mesh.size
				var rotation: Vector3 = wall.rotation_degrees
				
				result += "Wall: " + wall.name + "\n"
				result += "  Position: " + str(pos) + "\n"
				result += "  Size: " + str(size) + "\n"
				result += "  Rotation: " + str(rotation) + "\n"
				
				# Try to get additional information about wall connections
				if wall.has_meta("connected_to"):
					result += "  Connected to: " + str(wall.get_meta("connected_to")) + "\n"
				
				result += "\n"
	else:
		result += "No Walls node found\n\n"
	
	# Extract rooms data with more details
	var rooms_node: Node3D = house_building.get_node("Rooms")
	if rooms_node != null:
		result += "Detailed Room Data Extracted:\n"
		result += "==============================\n"
		
		for room in rooms_node.get_children():
			if room is MeshInstance3D:
				var pos: Vector3 = room.position
				var size: Vector3 = room.mesh.size
				var rotation: Vector3 = room.rotation_degrees
				
				result += "Room: " + room.name + "\n"
				result += "  Position: " + str(pos) + "\n"
				result += "  Size: " + str(size) + "\n"
				result += "  Rotation: " + str(rotation) + "\n"
				
				# Try to get room properties
				if room.has_meta("room_type"):
					result += "  Type: " + str(room.get_meta("room_type")) + "\n"
				
				if room.has_meta("room_id"):
					result += "  ID: " + str(room.get_meta("room_id")) + "\n"
				
				result += "\n"
	else:
		result += "No Rooms node found\n\n"
	
	# Extract room connections/relationships
	var connections_node: Node3D = house_building.get_node("Connections")
	if connections_node != null:
		result += "Room Connections:\n"
		result += "=================\n"
		
		for connection in connections_node.get_children():
			if connection is Node3D:
				result += "Connection: " + connection.name + "\n"
				result += "  From: " + str(connection.get_meta("from")) + "\n"
				result += "  To: " + str(connection.get_meta("to")) + "\n"
				result += "\n"
	
	return result

# Utility function to get all wall and room data in structured format
static func get_structured_data(node: Node) -> Dictionary:
	var data := {
		"walls": [],
		"rooms": [],
		"connections": []
	}
	
	var house_building: Node3D = node.get_node("../../BlueprintReference")
	if house_building == null:
		return data
	
	# Get walls
	var walls_node: Node3D = house_building.get_node("Walls")
	if walls_node != null:
		for wall in walls_node.get_children():
			if wall is MeshInstance3D:
				var wall_data := {
					"name": wall.name,
					"position": wall.position,
					"size": wall.mesh.size,
					"rotation": wall.rotation_degrees
				}
				
				# Add any metadata
				if wall.has_meta("connected_to"):
					wall_data["connected_to"] = wall.get_meta("connected_to")
					
				data["walls"].append(wall_data)
	
	# Get rooms
	var rooms_node: Node3D = house_building.get_node("Rooms")
	if rooms_node != null:
		for room in rooms_node.get_children():
			if room is MeshInstance3D:
				var room_data := {
					"name": room.name,
					"position": room.position,
					"size": room.mesh.size,
					"rotation": room.rotation_degrees
				}
				
				# Add any metadata
				if room.has_meta("room_type"):
					room_data["type"] = room.get_meta("room_type")
				if room.has_meta("room_id"):
					room_data["id"] = room.get_meta("room_id")
					
				data["rooms"].append(room_data)
	
	# Get connections
	var connections_node: Node3D = house_building.get_node("Connections")
	if connections_node != null:
		for connection in connections_node.get_children():
			if connection is Node3D:
				var conn_data := {
					"name": connection.name,
					"from": connection.get_meta("from"),
					"to": connection.get_meta("to")
				}
				data["connections"].append(conn_data)
	
	return data
