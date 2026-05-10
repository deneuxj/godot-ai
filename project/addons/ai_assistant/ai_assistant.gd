## AIAssistantPlugin - Plugin entry point.
## Registers the AgentAssisted3D node type and editor dock.

@tool
extends EditorPlugin


const AI_ASSISTED_3D_NODE = "res://addons/ai_assistant/agent_assisted_3d.gd"
const PANEL_SCENE = "res://addons/ai_assistant/agent_assisted_3d_panel.tscn"
const CHAT_PANEL_SCENE = "res://addons/ai_assistant/ai_chat_panel.tscn"
const CUSTOM_LOGGER = preload("res://addons/ai_assistant/generator/custom_logger.gd")

var _dock: Control = null
var _chat_dock: Control = null
var _logger: Logger = null


func _enter_tree() -> void:
	# Register custom logger for AI validation errors.
	_logger = CUSTOM_LOGGER.new()
	OS.add_logger(_logger)
	
	# Also register it with ScriptExecutor for easy access.
	ScriptExecutor.register_logger(_logger)

	_register_project_settings()
	_create_docks()
	add_control_to_bottom_panel(_dock, "Agent Assisted 3D")
	add_control_to_bottom_panel(_chat_dock, "AI Chat")


func _exit_tree() -> void:
	if _logger:
		OS.remove_logger(_logger)
	
	if _dock:
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()
	
	if _chat_dock:
		remove_control_from_bottom_panel(_chat_dock)
		_chat_dock.queue_free()


func _register_project_settings() -> void:
	# Connection Settings
	_set_setting("ai/connection/base_url", "http://localhost:1234", "Base URL for the AI API (e.g. http://localhost:1234)")

	_set_setting("ai/connection/api_key", "", "API Key for authentication")
	_set_setting("ai/connection/model", "local-model", "Model name to use")
	
	# Generation Settings
	_set_setting("ai/generation/max_tokens", 4096, "Max tokens in response", TYPE_INT, PROPERTY_HINT_RANGE, "1,32768,1")
	_set_setting("ai/generation/max_retries", 5, "Max correction attempts", TYPE_INT, PROPERTY_HINT_RANGE, "0,20,1")
	_set_setting("ai/generation/timeout_ms", 60000, "Request timeout in ms", TYPE_INT, PROPERTY_HINT_RANGE, "1000,300000,1000")
	_set_setting("ai/generation/system_prompt", "", "Custom system prompt override", TYPE_STRING, PROPERTY_HINT_MULTILINE_TEXT)
	
	# Tools Settings
	_set_setting("ai/tools/godot_source_path", "", "Path to the Godot source code checkout (for documentation).", TYPE_STRING, PROPERTY_HINT_GLOBAL_DIR)

	ProjectSettings.save()


func _set_setting(key: String, value: Variant, description: String = "", type: int = -1, hint: int = PROPERTY_HINT_NONE, hint_string: String = "") -> void:
	if not ProjectSettings.has_setting(key):
		ProjectSettings.set_setting(key, value)
	
	ProjectSettings.set_initial_value(key, value)
	
	var info := {
		"name": key,
		"type": type if type != -1 else typeof(value),
		"hint": hint,
		"hint_string": hint_string,
	}
	ProjectSettings.add_property_info(info)


func _create_docks() -> void:
	var dock_scene = load(PANEL_SCENE)
	_dock = dock_scene.instantiate()
	_dock.call("_init_editor", get_editor_interface())

	var chat_dock_scene = load(CHAT_PANEL_SCENE)
	_chat_dock = chat_dock_scene.instantiate()
	_chat_dock.call("_init_editor", get_editor_interface())
