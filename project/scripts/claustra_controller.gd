@tool
extends Node3D

@export_range(-90, 90) var blade_angle_degrees: float = 0.0 :
	set(val):
		blade_angle_degrees = val
		for child in get_children():
			if child.name.begins_with("Slat_"):
				child.rotation.y = deg_to_rad(val)
