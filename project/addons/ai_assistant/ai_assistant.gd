## AIAssistantPlugin - Plugin entry point.
## Registers the AgentAssisted3D node type and editor dock.

@tool
extends EditorPlugin


const AI_ASSISTED_3D_NODE = "res://agent_assisted_3d.gd"
const PANEL_SCENE = "res://agent_assisted_3d_panel.tscn"

var _dock: Control = null


func _enter_tree() -> void:
	_register_project_settings()
	_register_node_type()
	_create_dock()
	add_control_to_bottom_panel(_dock, "Agent Assisted 3D")


func _exit_tree() -> void:
	remove_control_from_bottom_panel(_dock)
	_dock.queue_free()


func _register_project_settings() -> void:
	if not ProjectSettings.has_setting("ai/openai/base_url"):
		ProjectSettings.set_setting("ai/openai/base_url", "http://localhost:1234/v1")
	if not ProjectSettings.has_setting("ai/openai/api_key"):
		ProjectSettings.set_setting("ai/openai/api_key", "")
	if not ProjectSettings.has_setting("ai/openai/model"):
		ProjectSettings.set_setting("ai/openai/model", "local-model")
	if not ProjectSettings.has_setting("ai/openai/max_tokens"):
		ProjectSettings.set_setting("ai/openai/max_tokens", 4096)
	if not ProjectSettings.has_setting("ai/openai/system_prompt"):
		ProjectSettings.set_setting("ai/openai/system_prompt", "")

	ProjectSettings.set_initial_value("ai/openai/base_url", "http://localhost:1234/v1")
	ProjectSettings.set_initial_value("ai/openai/api_key", "")
	ProjectSettings.set_initial_value("ai/openai/model", "local-model")
	ProjectSettings.set_initial_value("ai/openai/max_tokens", 4096)
	ProjectSettings.set_initial_value("ai/openai/system_prompt", "")

	ProjectSettings.save()


func _register_node_type() -> void:
	pass


func _create_dock() -> void:
	_dock = Control.new()
