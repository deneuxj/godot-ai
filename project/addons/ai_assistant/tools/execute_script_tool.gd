## ExecuteScriptTool - Allows the AI to execute arbitrary GDScript.
##
## The script MUST define a 'static func execute(node: Node)'.

class_name ExecuteScriptTool
extends AITool


func _init() -> void:
	super._init("execute_script", "Execute a GDScript that defines a 'static func execute(node: Node)' function. The 'node' argument is the context node (AIChat), allowing direct access to the scene tree for construction or manipulation.")


func get_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"script_content": {
				"type": "string",
				"description": "The complete GDScript source code. It MUST define a 'static func execute(node: Node)'."
			}
		},
		"required": ["script_content"]
	}


func execute(arguments: Dictionary) -> String:
	var script_content = arguments.get("script_content", "")

	if script_content.is_empty():
		return "Error: script_content is empty."

	# 1. Compile script
	var script = GDScript.new()
	script.source_code = script_content
	var reload_err = script.reload()
	if reload_err != OK:
		return "Error: Script compilation failed (Code: %d)." % reload_err

	# 2. Check for execute method
	if not script.has_method("execute"):
		return "Error: Script does not define a 'static func execute(node: Node)' function."

	# 3. Execute
	if context_node:
		script.call("execute", context_node)
		return "Successfully executed script via 'execute(node)'."
	else:
		return "Error: No context_node available for execution."
