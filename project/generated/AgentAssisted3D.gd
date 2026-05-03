func build() -> Node3D:
	var root = Node3D.new()
	root.name = "SheepScene"

	# Matériaux
	var mat_wool = StandardMaterial3D.new()
	mat_wool.albedo_color = Color(0.92, 0.92, 0.95)
	mat_wool.metallic = 0.0
	mat_wool.roughness = 1.0

	var mat_face = StandardMaterial3D.new()
	mat_face.albedo_color = Color(0.15, 0.15, 0.15)

	var mat_nose = StandardMaterial3D.new()
	mat_nose.albedo_color = Color(0.7, 0.3, 0.2)

	var mat_eye = StandardMaterial3D.new()
	mat_eye.albedo_color = Color(0.0, 0.0, 0.0)

	var mat_leg = StandardMaterial3D.new()
	mat_leg.albedo_color = Color(0.25, 0.25, 0.25)

	var mat_hoof = StandardMaterial3D.new()
	mat_hoof.albedo_color = Color(0.1, 0.1, 0.1)

	# Sol
	var ground = MeshInstance3D.new()
	ground.name = "Ground"
	var ground_m = BoxMesh.new()
	ground_m.size = Vector3(12, 0.1, 12)
	ground.mesh = ground_m
	ground.material_override = StandardMaterial3D.new()
	ground.material_override.albedo_color = Color(0.35, 0.6, 0.3)
	ground.position = Vector3(0, -1.5, 0)
	root.add_child(ground)

	# Corps
	var body = MeshInstance3D.new()
	body.name = "Body"
	var body_m = SphereMesh.new()
	body_m.radius = 1.0
	body_m.height = 1.4
	body.mesh = body_m
	body.material_override = mat_wool
	body.position = Vector3(0, 0, 0)
	root.add_child(body)

	# Tête
	var head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.6, 1.6)
	root.add_child(head)

	var head_mesh = MeshInstance3D.new()
	head_mesh.name = "HeadMesh"
	var head_m = SphereMesh.new()
	head_m.radius = 0.65
	head_mesh.mesh = head_m
	head_mesh.material_override = mat_wool
	head.add_child(head_mesh)

	# Museau
	var snout = MeshInstance3D.new()
	snout.name = "Snout"
	var snout_m = BoxMesh.new()
	snout_m.size = Vector3(0.5, 0.35, 0.6)
	snout.mesh = snout_m
	snout.material_override = mat_face
	snout.position = Vector3(0, -0.25, 0.5)
	head.add_child(snout)

	# Nez
	var nose = MeshInstance3D.new()
	nose.name = "Nose"
	var nose_m = SphereMesh.new()
	nose_m.radius = 0.12
	nose.mesh = nose_m
	nose.material_override = mat_nose
	nose.position = Vector3(0, 0.05, 0.35)
	head.add_child(nose)

	# Yeux
	var left_eye = MeshInstance3D.new()
	left_eye.name = "LeftEye"
	var eye_m = SphereMesh.new()
	eye_m.radius = 0.1
	left_eye.mesh = eye_m
	left_eye.material_override = mat_eye
	left_eye.position = Vector3(-0.35, 0.15, 0.45)
	head.add_child(left_eye)

	var right_eye = left_eye.duplicate()
	right_eye.name = "RightEye"
	right_eye.position = Vector3(0.35, 0.15, 0.45)
	head.add_child(right_eye)

	# Oreilles
	var left_ear = MeshInstance3D.new()
	left_ear.name = "LeftEar"
	var ear_m = CylinderMesh.new()
	ear_m.top_radius = 0.15
	ear_m.bottom_radius = 0.05
	ear_m.height = 0.4
	left_ear.mesh = ear_m
	left_ear.material_override = mat_face
	left_ear.position = Vector3(-0.5, 0.5, 0.2)
	left_ear.rotation.z = PI / 3
	head.add_child(left_ear)

	var right_ear = left_ear.duplicate()
	right_ear.name = "RightEar"
	right_ear.position = Vector3(0.5, 0.5, 0.2)
	right_ear.rotation.z = -PI / 3
	head.add_child(right_ear)

	# Boucles de laine
	var wool_offsets = [
		Vector3(0, 1.0, 0), Vector3(-0.8, 0.8, 0.4), Vector3(0.8, 0.8, 0.4),
		Vector3(-0.6, 0.4, 0.8), Vector3(0.6, 0.4, 0.8), Vector3(0, 0.1, 1.0),
		Vector3(-0.9, 1.0, -0.3), Vector3(0.9, 1.0, -0.3), Vector3(0, 0.8, -0.6),
		Vector3(-0.7, 1.2, 0.2), Vector3(0.7, 1.2, 0.2), Vector3(0, 1.3, 0.1),
		Vector3(-1.0, 0.5, 0.1), Vector3(1.0, 0.5, 0.1), Vector3(0, 0.6, -0.5)
	]

	for i in range(wool_offsets.size()):
		var wool = MeshInstance3D.new()
		wool.name = "Wool" + str(i)
		var wool_m = SphereMesh.new()
		wool_m.radius = 0.25 + randf() * 0.15
		wool.mesh = wool_m
		wool.material_override = mat_wool
		wool.position = wool_offsets[i]
		root.add_child(wool)

	# Pattes
	var leg_data = [
		{"pos": Vector3(-0.5, -1.1, 0.6), "name": "FrontLeftLeg"},
		{"pos": Vector3(0.5, -1.1, 0.6), "name": "FrontRightLeg"},
		{"pos": Vector3(-0.5, -1.1, -0.6), "name": "BackLeftLeg"},
		{"pos": Vector3(0.5, -1.1, -0.6), "name": "BackRightLeg"}
	]

	for leg_info in leg_data:
		var leg = MeshInstance3D.new()
		leg.name = leg_info["name"]
		var leg_m = CylinderMesh.new()
		leg_m.top_radius = 0.14
		leg_m.bottom_radius = 0.12
		leg_m.height = 1.2
		leg.mesh = leg_m
		leg.material_override = mat_leg
		leg.position = leg_info["pos"]
		root.add_child(leg)

		# Sabots
		var hoof = MeshInstance3D.new()
		hoof.name = leg_info["name"] + "Hoof"
		var hoof_m = CylinderMesh.new()
		hoof_m.top_radius = 0.13
		hoof_m.bottom_radius = 0.10
		hoof_m.height = 0.15
		hoof.mesh = hoof_m
		hoof.material_override = mat_hoof
		hoof.position = leg_info["pos"] + Vector3(0, -0.6, 0)
		root.add_child(hoof)

	# Queue
	var tail = MeshInstance3D.new()
	tail.name = "Tail"
	var tail_m = CylinderMesh.new()
	tail_m.top_radius = 0.12
	tail_m.bottom_radius = 0.08
	tail_m.height = 0.5
	tail.mesh = tail_m
	tail.material_override = mat_wool
	tail.position = Vector3(0, 0.4, -1.1)
	tail.rotation.x = PI / 4
	root.add_child(tail)

	# Éclairage
	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.95, 0.8)
	sun.rotation_degrees = Vector3(45, -45, 0)
	sun.shadow_enabled = true
	root.add_child(sun)

	var fill = OmniLight3D.new()
	fill.name = "FillLight"
	fill.light_color = Color(0.6, 0.7, 0.9)
	fill.position = Vector3(-3, 4, 3)
	fill.light_energy = 0.6
	root.add_child(fill)

	return root