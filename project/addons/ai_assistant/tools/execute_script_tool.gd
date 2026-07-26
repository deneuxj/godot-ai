## ExecuteScriptTool - Allows the AI to execute arbitrary GDScript.
##
## The script MUST define a 'static func execute(node: Node)'.

# REQ-TOOL-0008: build_dynamic_scene (execute_script) tool
class_name ExecuteScriptTool
# REQ-TOOL-0008: build_dynamic_scene (execute_script) tool
extends AITool

const ScriptExecutor = preload("res://addons/ai_assistant/generator/script_executor.gd")


func _init() -> void:
	super._init("execute_script", "Execute a GDScript that defines a 'static func execute(node: Node)' function. The 'node' argument is the context node (AIChat), allowing direct access to the scene tree for construction or manipulation.")


func get_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"script_content": {
				"type": "string",
				"description": "The complete GDScript source code. It MUST define a 'static func execute(node: Node)'."
			},
			"reload_editor_scene": {
				"type": "boolean",
				"description": "If true, reloads the current editor scene after executing the script to reflect changes visually. Set to true if your script modifies the currently open scene.",
				"default": false
			}
		},
		"required": ["script_content"]
	}


func execute(arguments: Dictionary) -> String:
	var script_content = arguments.get("script_content", "")
	var reload_editor_scene = arguments.get("reload_editor_scene", false)

	if script_content.is_empty():
		return "Error: script_content is empty."

	# 1. Compile script
	var logger = ScriptExecutor._get_logger()
	if logger:
		logger.call("start_capture")

	var script = GDScript.new()
	script.source_code = script_content
	var reload_err = script.reload()
	
	if reload_err != OK:
		var err_msg = "Error: Script compilation failed (Code: %d)." % reload_err
		if logger:
			logger.call("stop_capture")
			var captured = logger.call("get_captured_errors")
			if not captured.is_empty():
				err_msg += "\nDetails:\n" + captured
		return err_msg

	if logger:
		# Keep capturing for execution
		pass

	# 2. Check for execute method
	if not script.has_method("execute"):
		return "Error: Script does not define a 'static func execute(node: Node)' function."

	# 3. Execute with error capture
	if not context_node:
		return "Error: No context_node available for execution."
		
	var return_value = script.call("execute", context_node)
	
	var result_msg = "Successfully executed script via 'execute(node)'."

	# 4. Handle return value if it's an easily printable type
	match typeof(return_value):
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, \
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_RECT2, TYPE_RECT2I, \
		TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I, \
		TYPE_COLOR, TYPE_STRING_NAME, TYPE_ARRAY, TYPE_DICTIONARY:
			result_msg += "\nReturn value: " + str(return_value)

	if logger:
		logger.call("stop_capture")
		var captured = logger.call("get_captured_errors")
		if not captured.is_empty():
			result_msg = "Error: Script executed but encountered runtime errors:\n" + captured

	if reload_editor_scene and Engine.is_editor_hint():
		var edited_scene = EditorInterface.get_edited_scene_root()
		if edited_scene and not edited_scene.scene_file_path.is_empty():
			EditorInterface.reload_scene_from_path(edited_scene.scene_file_path)
			result_msg += "\nNote: The current editor scene was reloaded."

	return result_msg
