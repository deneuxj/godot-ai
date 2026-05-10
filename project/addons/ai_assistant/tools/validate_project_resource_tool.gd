## ValidateProjectResourceTool - Allows the AI to validate project resources.

class_name ValidateProjectResourceTool
extends AITool

const ScriptExecutor = preload("res://addons/ai_assistant/generator/script_executor.gd")


func _init() -> void:
	super._init("validate_project_resource", "Validate a project resource (script, scene, or data resource) and return any engine errors or warnings.")


func get_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"path": {
				"type": "string",
				"description": "The res:// path to the resource to validate."
			}
		},
		"required": ["path"]
	}


func execute(arguments: Dictionary) -> String:
	var path = arguments.get("path", "")
	if not path.begins_with("res://"):
		path = "res://" + path

	if not FileAccess.file_exists(path):
		return "Error: Resource '%s' does not exist." % path

	var logger = ScriptExecutor._get_logger()
	if logger:
		logger.call("start_capture")

	var result_msg := ""
	var ext = path.get_extension().to_lower()
	
	if ext == "gd":
		result_msg = _validate_script(path)
	else:
		result_msg = _validate_general_resource(path)

	if logger:
		logger.call("stop_capture")
		var captured = logger.call("get_captured_errors")
		if not captured.is_empty():
			result_msg += "\n\nEngine Logs/Errors:\n" + captured

	return result_msg


func _validate_script(path: String) -> String:
	var script = load(path) as GDScript
	if not script:
		return "Error: Failed to load script '%s'." % path
	
	var err = script.reload()
	if err == OK:
		return "Success: Script '%s' parsed correctly." % path
	else:
		return "Error: Script '%s' has parse errors (code %d)." % [path, err]


func _validate_general_resource(path: String) -> String:
	# Attempt to load the resource to trigger validation/dependency checks
	var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if res:
		return "Success: Resource '%s' loaded correctly." % path
	else:
		return "Error: Failed to load resource '%s'. Check engine logs for details." % path
