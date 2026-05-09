extends RefCounted

# House generation script based on the Hartmann Bois blueprint
# Scale: 1m = 1 unit
# Outer walls only.

func build() -> Node3D:
	var root = Node3D.new()
	root.name = "House_Walls"

	var wall_height = 2.50
	var wall_thickness = 0.52 # Using 52cm from the blueprint markers
	
	# Material for the walls
	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.9, 0.88, 0.85) # Off-white/Beige
	wall_mat.roughness = 0.8

	# Define the outer perimeter vertices (X, Z) based on blueprint markers
	# X goes from 0 (Right) to 23.45 (Left)
	# Z goes from 0 (Bottom) to 13.44 (Top)
	var points = [
		Vector2(23.45, 6.20),  # 0: Garage bottom-left
		Vector2(23.45, 13.44), # 1: Garage top-left
		Vector2(17.55, 13.44), # 2: Garage top-right
		Vector2(17.55, 13.12), # 3: House top-left transition
		Vector2(0.00, 13.12),  # 4: House top-right
		Vector2(0.00, 4.51),   # 5: House bottom-right
		Vector2(7.54, 4.51),   # 6: Right transition to Dining room
		Vector2(7.54, 0.00),   # 7: Dining room bottom-right
		Vector2(12.56, 0.00),  # 8: Dining room bottom-left
		Vector2(12.56, 4.51),  # 9: Left transition from Dining room
		Vector2(17.55, 4.51),  # 10: Living room bottom-left
		Vector2(17.55, 6.20)   # 11: Back to Garage corner
	]

	# Build walls between consecutive points
	for i in range(points.size()):
		var p1 = points[i]
		var p2 = points[(i + 1) % points.size()]
		
		var wall = create_wall(p1, p2, wall_height, wall_thickness, wall_mat)
		if wall:
			root.add_child(wall)
			wall.name = "WallSegment_" + str(i)

	return root

func create_wall(p1: Vector2, p2: Vector2, height: float, thickness: float, material: Material) -> MeshInstance3D:
	var diff = p2 - p1
	var length = diff.length()
	
	if length < 0.01:
		return null
		
	var center = (p1 + p2) / 2.0
	var angle = atan2(diff.y, diff.x)
	
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(length, height, thickness)
	mesh_inst.mesh = box
	mesh_inst.material_override = material
	
	# Godot 3D space: X, Y (vertical), Z
	# Position the box at the midpoint of the segment
	mesh_inst.position = Vector3(center.x, height / 2.0, center.y)
	
	# Rotate the box around Y to align with the segment
	# Note: BoxMesh length is along X, so we rotate X to point towards the segment direction
	mesh_inst.rotation.y = -angle
	
	return mesh_inst
