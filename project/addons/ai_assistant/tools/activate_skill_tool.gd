## ActivateSkillTool - Built-in tool to activate specialized AI skills.

class_name ActivateSkillTool
extends AITool

func _init():
	super("activate_skill", "Activates a specialized skill by name. Returns the skill's instructions and registers its tools.")


func get_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"name": { 
				"type": "string", 
				"description": "The name (ID) of the skill to activate." 
			}
		},
		"required": ["name"]
	}


func execute(arguments: Dictionary) -> String:
	var name = arguments.get("name", "")
	if name.is_empty():
		return "Error: No skill name provided."
	
	# The execution is actually handled as a stateful transition in AIRequestHandler.
	# This tool's 'execute' method is called by the handler, which then returns 
	# the result of its own internal 'activate_skill' call.
	
	# However, to be robust if called directly:
	if context_node and context_node.get("request_handler"):
		var handler = context_node.request_handler
		if handler and handler.has_method("activate_skill"):
			return await handler.activate_skill(name)
			
	return "Error: Skill activation not supported in this context."
