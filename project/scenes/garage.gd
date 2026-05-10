extends Node3D
class_name GarageWalls

# Garage external wall definitions (left, bottom, top)
var garage_wall_thickness = 0.50
var garage_height = 7.249
var garage_width = 5.99

func build() -> Node:
	# Left Wall: External from (0, 0) to (0, 7.249)
	var left_wall := StaticBody3D.new()
	left_wall.name = "Left_Wall"
	
	var left_collision := CollisionShape3D.new()
	var left_shape := BoxShape3D.new()
	left_shape.size = Vector3(garage_wall_thickness, garage_height, garage_width)
	left_collision.shape = left_shape
	left_collision.position = Vector3(-garage_wall_thickness / 2, garage_height / 2, -garage_width / 2)
	left_wall.add_child(left_collision)
	
	var left_mesh_instance := MeshInstance3D.new()
	var left_mesh := BoxMesh.new()
	left_mesh.size = Vector3(garage_wall_thickness, garage_height, garage_width)
	left_mesh_instance.mesh = left_mesh
	left_mesh_instance.position = Vector3(-garage_wall_thickness / 2, garage_height / 2, -garage_width / 2)
	left_wall.add_child(left_mesh_instance)
	
	# Top Wall: External from (0, 7.249) to (5.99, 7.249)
	var top_wall := StaticBody3D.new()
	top_wall.name = "Top_Wall"
	
	var top_collision := CollisionShape3D.new()
	var top_shape := BoxShape3D.new()
	top_shape.size = Vector3(garage_width, garage_wall_thickness, garage_height)
	top_collision.shape = top_shape
	top_collision.position = Vector3(-garage_width / 2, garage_height + garage_wall_thickness / 2, -garage_width / 2)
	top_wall.add_child(top_collision)
	
	var top_mesh_instance := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(garage_width, garage_wall_thickness, garage_height)
	top_mesh_instance.mesh = top_mesh
	top_mesh_instance.position = Vector3(-garage_width / 2, garage_height + garage_wall_thickness / 2, -garage_width / 2)
	top_wall.add_child(top_mesh_instance)
	
	# Bottom Wall: External from (0, 0) to (5.99, 0)
	var bottom_wall := StaticBody3D.new()
	bottom_wall.name = "Bottom_Wall"
	
	var bottom_collision := CollisionShape3D.new()
	var bottom_shape := BoxShape3D.new()
	bottom_shape.size = Vector3(garage_width, garage_wall_thickness, garage_height)
	bottom_collision.shape = bottom_shape
	bottom_collision.position = Vector3(-garage_width / 2, -garage_wall_thickness / 2, -garage_width / 2)
	bottom_wall.add_child(bottom_collision)
	
	var bottom_mesh_instance := MeshInstance3D.new()
	var bottom_mesh := BoxMesh.new()
	bottom_mesh.size = Vector3(garage_width, garage_wall_thickness, garage_height)
	bottom_mesh_instance.mesh = bottom_mesh
	bottom_mesh_instance.position = Vector3(-garage_width / 2, -garage_wall_thickness / 2, -garage_width / 2)
	bottom_wall.add_child(bottom_mesh_instance)
	
	# Garage walls container
	var wall_container := Node3D.new()
	wall_container.name = "Garage_Walls"
	wall_container.add_child(left_wall)
	wall_container.add_child(top_wall)
	wall_container.add_child(bottom_wall)
	
	return wall_container
