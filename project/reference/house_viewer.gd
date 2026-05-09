extends Node3D

func _ready():
	var builder = preload("res://reference/generate_house.gd").new()
	var house = builder.build()
	add_child(house)
