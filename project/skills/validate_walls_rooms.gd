class_name ValidateWallsRoomsSkill
extends Node

# Skill to validate walls and rooms data for consistency and correctness
static func execute(node: Node) -> String:
	var result := ""
	
	# Get the blueprint reference node
	var house_building: Node3D = node.get_node("../../BlueprintReference")
	if house_building == null:
		return "Error: BlueprintReference node not found"
	
	result += "Data Validation Results:\n"
	result += "========================\n\n"
	
	var validation_errors := []
	var validation_warnings := []
	
	# Validate walls
	var walls_node: Node3D = house_building.get_node("Walls")
	if walls_node != null:
		result += "Validating Walls:\n"
		result += "------------------\n"
		
		for wall in walls_node.get_children():
			if wall is MeshInstance3D:
				# Check if mesh exists
				if wall.mesh == null:
					validation_errors.append("Wall '" + wall.name + "' has no mesh assigned")
				
				# Check for valid size values
				if wall.mesh != null and wall.mesh.size.x <= 0:
					validation_errors.append("Wall '" + wall.name + "' has invalid width (x)")
				if wall.mesh != null and wall.mesh.size.y <= 0:
					validation_errors.append("Wall '" + wall.name + "' has invalid height (y)")
				if wall.mesh != null and wall.mesh.size.z <= 0:
					validation_errors.append("Wall '" + wall.name + "' has invalid depth (z)")
				
				# Check for valid position
				if wall.position.x.is_nan() or wall.position.y.is_nan() or wall.position.z.is_nan():
					validation_errors.append("Wall '" + wall.name + "' has invalid position")
					
		result += "Walls validation completed\n\n"
	else:
		validation_warnings.append("No Walls node found in BlueprintReference")
	
	# Validate rooms
	var rooms_node: Node3D = house_building.get_node("Rooms")
	if rooms_node != null:
		result += "Validating Rooms:\n"
		result += "-----------------\n"
		
		for room in rooms_node.get_children():
			if room is MeshInstance3D:
				# Check if mesh exists
				if room.mesh == null:
					validation_errors.append("Room '" + room.name + "' has no mesh assigned")
				
				# Check for valid size values
				if room.mesh != null and room.mesh.size.x <= 0:
					validation_errors.append("Room '" + room.name + "' has invalid width (x)")
				if room.mesh != null and room.mesh.size.y <= 0:
					validation_errors.append("Room '" + room.name + "' has invalid height (y)")
				if room.mesh != null and room.mesh.size.z <= 0:
					validation_errors.append("Room '" + room.name + "' has invalid depth (z)")
				
				# Check for valid position
				if room.position.x.is_nan() or room.position.y.is_nan() or room.position.z.is_nan():
					validation_errors.append("Room '" + room.name + "' has invalid position")
					
		result += "Rooms validation completed\n\n"
	else:
		validation_warnings.append("No Rooms node found in BlueprintReference")
	
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

# Utility function to get validation results as structured data
static func get_validation_results(node: Node) -> Dictionary:
	var results := {
		"errors": [],
		"warnings": [],
		"status": "valid"
	}
	
	var house_building: Node3D = node.get_node("../../BlueprintReference")
	if house_building == null:
		results["errors"].append("BlueprintReference node not found")
		results["status"] = "invalid"
		return results
	
	# Validate walls
	var walls_node: Node3D = house_building.get_node("Walls")
	if walls_node != null:
		for wall in walls_node.get_children():
			if wall is MeshInstance3D:
				if wall.mesh == null:
					results["errors"].append("Wall '" + wall.name + "' has no mesh assigned")
				
				# Check size values
				if wall.mesh != null:
					if wall.mesh.size.x <= 0:
						results["errors"].append("Wall '" + wall.name + "' has invalid width")
					if wall.mesh.size.y <= 0:
						results["errors"].append("Wall '" + wall.name + "' has invalid height")
					if wall.mesh.size.z <= 0:
						results["errors"].append("Wall '" + wall.name + "' has invalid depth")
				
				# Check position
				if wall.position.x.is_nan() or wall.position.y.is_nan() or wall.position.z.is_nan():
					results["errors"].append("Wall '" + wall.name + "' has invalid position")
	
	# Validate rooms
	var rooms_node: Node3D = house_building.get_node("Rooms")
	if rooms_node != null:
		for room in rooms_node.get_children():
			if room is MeshInstance3D:
				if room.mesh == null:
					results["errors"].append("Room '" + room.name + "' has no mesh assigned")
				
				# Check size values
				if room.mesh != null:
					if room.mesh.size.x <= 0:
						results["errors"].append("Room '" + room.name + "' has invalid width")
					if room.mesh.size.y <= 0:
						results["errors"].append("Room '" + room.name + "' has invalid height")
					if room.mesh.size.z <= 0:
						results["errors"].append("Room '" + room.name + "' has invalid depth")
				
				# Check position
				if room.position.x.is_nan() or room.position.y.is_nan() or room.position.z.is_nan():
					results["errors"].append("Room '" + room.name + "' has invalid position")
	
	# Set status based on errors
	if results["errors"].size() > 0:
		results["status"] = "invalid"
	else:
		results["status"] = "valid"
		
	return results
