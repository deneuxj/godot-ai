## Apply stucco material to all outer walls in the HouseBuilding scene.
## Outer walls are identified by names that don't match any room name pattern.
static func execute(node: Node) -> void:
	# Load the materials scene to get the stucco material
	var materials_scene: PackedScene = load("res://materials.tscn")
	var materials_node: Node3D = materials_scene.instantiate()
	node.add_child(materials_node)
	
	# Find the stucco ShaderMaterial (it's the one using stucco.gdshader)
	var stucco_material: ShaderMaterial = null
	for child in materials_node.get_children():
		if child is MeshInstance3D:
			var mat: Material = child.get_surface_material(0)
			if mat is ShaderMaterial:
				var shader: Shader = mat.get_shader()
				if shader and shader.resource_path == "res://shaders/stucco.gdshader":
					stucco_material = mat
					break
	
	if stucco_material == null:
		printerr("Stucco material not found in materials.tscn")
		return
	
	print("Applying stucco material to outer walls...")
	
	# Get all walls
	var walls_node: Node3D = node.get_node_or_null("Walls")
	if walls_node == null:
		printerr("Walls node not found")
		return
	
	# Get room names to identify inner walls
	var rooms_node: Node3D = node.get_node_or_null("Rooms")
	var room_names: Array[String] = []
	if rooms_node:
		for room in rooms_node.get_children():
			if room is Node3D:
				room_names.append(room.name)
	
	# Also check Generated node for rooms
	var generated_node: Node3D = node.get_node_or_null("Generated")
	if generated_node:
		for child in generated_node.get_children():
			if child is Node3D:
				room_names.append(child.name)
	
	var outer_wall_count: int = 0
	var inner_wall_count: int = 0
	
	for wall in walls_node.get_children():
		if wall is CSGCombiner3D or wall is MeshInstance3D:
			var wall_name: String = wall.name
			
			# Check if this wall is an outer wall
			# Outer walls typically contain: MAISON, GARAGE (as prefix), CELIER-EXTERIEUR, SEJOUR_ARRIERE, etc.
			# Inner walls have names like "ROOM1-ROOM2" pattern (two room names separated by - or _)
			
			var is_outer_wall: bool = false
			
			# Check for outer wall naming patterns
			if wall_name.begins_with("MAISON"):
				is_outer_wall = true
			elif wall_name.begins_with("GARAGE_"):
				is_outer_wall = true
			elif wall_name == "CELIER-EXTERIEUR":
				is_outer_wall = true
			elif wall_name == "SEJOUR_ARRIERE":
				is_outer_wall = true
			elif wall_name == "SALLE_A_MANGER_ARRIERE":
				is_outer_wall = true
			elif wall_name == "SALLE_A_MANGER_DROITE":
				is_outer_wall = true
			elif wall_name == "CHAMBRES_ARRIERE":
				is_outer_wall = true
			elif wall_name == "SALLE_A_MANGER_GAUCHE":
				is_outer_wall = true
			elif wall_name == "SALLE_DE_BAIN_GAUCHE":
				is_outer_wall = true
			elif wall_name == "WC_GAUCHE":
				is_outer_wall = true
			elif wall_name == "WC_DROITE":
				is_outer_wall = true
			elif wall_name == "WC-WALL":
				is_outer_wall = true
			elif wall_name == "ENTREE-BUREAU":
				is_outer_wall = true
			elif wall_name == "GARAGE-SEJOUR":
				is_outer_wall = true
			elif wall_name == "SEJOUR-CELIER":
				is_outer_wall = true
			
			if is_outer_wall:
				# Apply stucco material to the CSGCombiner3D itself
				if wall is CSGCombiner3D:
					wall.set_surface_material_override(0, stucco_material)
					print("Applied stucco to outer wall: ", wall_name)
					outer_wall_count += 1
				# For MeshInstance3D walls, apply to surface material
				elif wall is MeshInstance3D:
					wall.set_surface_material(0, stucco_material)
					print("Applied stucco to outer wall: ", wall_name)
					outer_wall_count += 1
	
	print("Stucco application complete: ", outer_wall_count, " outer walls styled. ", inner_wall_count, " inner walls left untouched.")
