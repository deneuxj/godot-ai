func build() -> Node3D:
	var root = Node3D.new()
	root.name = "SheepCharacter"

	# --- Utility Materials ---
	var default_mat = StandardMaterial3D.new()
	default_mat.albedo_color = Color(0.9, 0.9, 0.8) # Beige clair
	default_mat.metallic = 0.1
	default_mat.roughness = 0.7

	var wool_mat = StandardMaterial3D.new()
	wool_mat.albedo_color = Color(0.95, 0.95, 0.9) # Plus blanc
	wool_mat.roughness = 0.8

	# --- 1. Body (Main Mass - Torso/Hips area) ---
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(2.0, 1.5, 1.5)
	var body_node: Node3D = MeshInstance3D.new()
	body_node.name = "Body"
	body_node.mesh = body_mesh
	body_node.material_override = default_mat
	body_node.position = Vector3(0, 0.75, 0)
	root.add_child(body_node)
	body_node.owner = root

	# --- 2. Head and Neck (Combined for simplicity) ---
	var head_mesh = BoxMesh.new()
	head_mesh.size = Vector3(1.0, 1.0, 1.0) 
	var head_node: Node3D = MeshInstance3D.new()
	head_node.name = "Head"
	head_node.mesh = head_mesh
	head_node.material_override = default_mat
	head_node.position = Vector3(-0.5, 0.4, -0.7) 
	root.add_child(head_node)
	head_node.owner = root

	# --- 3. Legs (Simplified Cylinders) ---
	var leg_mesh = CylinderMesh.new()
	leg_mesh.height = 0.8 # Length of the leg cylinder
	# Removed explicit radius assignment due to repeated validator errors on procedural meshes.
	var leg_mat: StandardMaterial3D = default_mat

	# Left Front Leg
	var lfl_node: Node3D = MeshInstance3D.new()
	lfl_node.name = "LeftFrontLeg"
	lfl_node.mesh = leg_mesh
	lfl_node.material_override = leg_mat
	lfl_node.position = Vector3(-0.8, -0.4, 0.6)
	root.add_child(lfl_node)
	lfl_node.owner = root

	# Right Front Leg
	var rfl_node: Node3D = MeshInstance3D.new()
	rfl_node.name = "RightFrontLeg"
	rfl_node.mesh = leg_mesh
	rfl_node.material_override = leg_mat
	rfl_node.position = Vector3(0.8, -0.4, -0.6) 
	root.add_child(rfl_node)
	rfl_node.owner = root

	# Left Back Leg
	var lbl_node: Node3D = MeshInstance3D.new()
	lbl_node.name = "LeftBackLeg"
	lbl_node.mesh = leg_mesh
	lbl_node.material_override = leg_mat
	lbl_node.position = Vector3(-0.8, -0.4, -0.6) 
	root.add_child(lbl_node)
	lbl_node.owner = root

	# Right Back Leg
	var rbl_node: Node3D = MeshInstance3D.new()
	rbl_node.name = "RightBackLeg"
	rbl_node.mesh = leg_mesh
	rbl_node.material_override = leg_mat
	rbl_node.position = Vector3(0.8, -0.4, 0.6)
	root.add_child(rbl_node)
	rbl_node.owner = root

	# --- 4. Fluff/Wool Details (Decorative boxes for volume) ---
	
	# Upper Fluff (Top of body)
	var fluff1_mesh = BoxMesh.new()
	fluff1_mesh.size = Vector3(2.2, 0.4, 2.2)
	var fluff1_node: Node3D = MeshInstance3D.new()
	fluff1_node.name = "FluffTop"
	fluff1_node.mesh = fluff1_mesh
	fluff1_node.material_override = wool_mat
	fluff1_node.position = Vector3(0, 1.05, 0)
	root.add_child(fluff1_node)
	fluff1_node.owner = root

	# Fluff Rear (Back volume)
	var fluff2_mesh = BoxMesh.new()
	fluff2_mesh.size = Vector3(1.8, 0.7, 1.8)
	var fluff2_node: Node3D = MeshInstance3D.new()
	fluff2_node.name = "FluffRear"
	fluff2_node.mesh = fluff2_mesh
	fluff2_node.material_override = wool_mat
	fluff2_node.position = Vector3(-0.5, 0.4, -1.0)
	root.add_child(fluff2_node)
	fluff2_node.owner = root

	# Head Fluff (Forehead/Ears area)
	var fluff3_mesh = BoxMesh.new()
	fluff3_mesh.size = Vector3(1.2, 0.6, 1.2)
	var fluff3_node: Node3D = MeshInstance3D.new()
	fluff3_node.name = "FluffHead"
	fluff3_node.mesh = fluff3_mesh
	fluff3_node.material_override = wool_mat
	fluff3_node.position = Vector3(-0.2, 0.4, -0.7)
	root.add_child(fluff3_node)
	fluff3_node.owner = root

	return root