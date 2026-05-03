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

	_create_dock()
	add_control_to_bottom_panel(_dock, "Agent Assisted 3D")


func _exit_tree() -> void:
	if _logger:
		OS.remove_logger(_logger)
	
	if _dock:
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()


func _create_dock() -> void:
	var dock_scene = load(PANEL_SCENE)
	_dock = dock_scene.instantiate()
	_dock.call("_init_editor", get_editor_interface())
