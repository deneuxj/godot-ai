extends Node3D

func _ready():
	# Create the main body of the sheep (a large sphere)
	var body = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 1.0
	sphere_mesh.height = 1.2
	body.mesh = sphere_mesh
	body.position = Vector3(0, 1.0, 0)
	
	# Create a basic white material for the sheep
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 0.95)
	body.material_override = mat
	
	add_child(body)
	
	# Create the head (a smaller sphere)
	var head = MeshInstance3D.new()
	var head_mesh = SphereMesh.new()
	head_mesh.radius = 0.4
	head_mesh.height = 0.5
	head.mesh = head_mesh
	head.position = Vector3(0, 1.6, 0.8)
	head.material_override = mat
	add_child(head)
	
	# Create the legs (4 cylinders)
	var leg_positions = [
		Vector3(-0.4, 0, 0.4),
		Vector3(0.4, 0, 0.4),
		Vector3(-0.4, 0, -0.4),
		Vector3(0.4, 0, -0.4)
	]
	
	for leg_pos in leg_positions:
		var leg = MeshInstance3D.new()
		var leg_mesh = CylinderMesh.new()
		leg_mesh.top_radius = 0.1
		leg_mesh.bottom_radius = 0.1
		leg_mesh.height = 0.8
		leg.mesh = leg_mesh
		leg.position = leg_pos
		leg.position.y = 0.4 # Center the cylinder on the foot
		leg.material_override = mat
		add_child(leg)
		
	# Add a small directional light to see the model better
	var light = DirectionalLight3D.new()
	light.position = Vector3(2, 4, 3)
	light.rotation_degrees = Vector3(-45, -45, 0)
	add_child(light)
