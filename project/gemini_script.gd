extends Node3D

func _ready():
    $AIChat.api_key = ""
    $AIChat.send_message("Write a very short poem about the Godot Engine.")
