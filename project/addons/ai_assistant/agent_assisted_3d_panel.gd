## AgentAssisted3DPanel - Editor dock UI controller for the AgentAssisted3D node.

extends Control


var _current_node: AgentAssisted3D = null


func _ready() -> void:
	pass


func _on_generate_pressed() -> void:
	if _current_node:
		_current_node.force_generate()
