## AIAssistantPlugin - Plugin entry point.
## Registers the AgentAssisted3D node type and editor dock.

@tool
extends EditorPlugin


const AI_SETTINGS = "res://addons/ai_assistant/settings/ai_settings.gd"
const AI_ASSISTED_3D_NODE = "res://addons/ai_assistant/agent_assisted_3d.gd"
const PANEL_SCENE = "res://addons/ai_assistant/agent_assisted_3d_panel.tscn"
const CUSTOM_LOGGER = preload("res://addons/ai_assistant/generator/custom_logger.gd")

var _dock: Control = null
var _logger: Logger = null


func _enter_tree() -> void:
	# Register custom logger for AI validation errors.
	_logger = CUSTOM_LOGGER.new()
	OS.add_logger(_logger)
	
	# Also register it with ScriptExecutor for easy access.
	ScriptExecutor.register_logger(_logger)

	# Ensure AI project settings exist before anything reads them.
	var settings = load(AI_SETTINGS)
	if settings:
		settings.call("ensure_settings_exist")

	_register_project_settings()
	_create_dock()
	add_control_to_bottom_panel(_dock, "Agent Assisted 3D")


func _exit_tree() -> void:
	if _logger:
		# OS.remove_logger is the expected counterpart to add_logger
		OS.remove_logger(_logger)
	remove_control_from_bottom_panel(_dock)
	_dock.queue_free()


func _register_project_settings() -> void:
	if not ProjectSettings.has_setting("ai/openai/base_url"):
		ProjectSettings.set_setting("ai/openai/base_url", "http://localhost:1234")
	if not ProjectSettings.has_setting("ai/openai/api_key"):
		ProjectSettings.set_setting("ai/openai/api_key", "")
	if not ProjectSettings.has_setting("ai/openai/model"):
		ProjectSettings.set_setting("ai/openai/model", "local-model")
	if not ProjectSettings.has_setting("ai/openai/max_tokens"):
		ProjectSettings.set_setting("ai/openai/max_tokens", 8192)
	if not ProjectSettings.has_setting("ai/openai/system_prompt"):
		ProjectSettings.set_setting("ai/openai/system_prompt", "")

	ProjectSettings.set_initial_value("ai/openai/base_url", "http://localhost:1234")
	ProjectSettings.set_initial_value("ai/openai/api_key", "")
	ProjectSettings.set_initial_value("ai/openai/model", "local-model")
	ProjectSettings.set_initial_value("ai/openai/max_tokens", 8192)
	ProjectSettings.set_initial_value("ai/openai/system_prompt", "")

	ProjectSettings.save()


func _create_dock() -> void:
	var dock_scene = load(PANEL_SCENE)
	_dock = dock_scene.instantiate()
	_dock.call("_init_editor", get_editor_interface())
