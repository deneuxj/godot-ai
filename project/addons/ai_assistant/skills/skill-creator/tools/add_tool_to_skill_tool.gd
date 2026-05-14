## AddToolToSkillTool - Tool to add a GDScript tool to a skill.

class_name AddToolToSkillTool
extends AITool

func _init():
	super("add_tool_to_skill", "Adds a specialized GDScript tool to an existing AI skill.")


func get_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"skill_name": { 
				"type": "string", 
				"description": "The name of the skill (folder name)." 
			},
			"tool_name": {
				"type": "string",
				"description": "The filename for the tool (e.g. 'tweaker_tool.gd')."
			},
			"script_content": {
				"type": "string",
				"description": "The complete GDScript content for the tool class."
			}
		},
		"required": ["skill_name", "tool_name", "script_content"]
	}


func execute(arguments: Dictionary) -> String:
	var skill_name = arguments.get("skill_name", "").to_lower().replace(" ", "-")
	var tool_name = arguments.get("tool_name", "")
	var script_content = arguments.get("script_content", "")
	
	if not tool_name.ends_with(".gd"):
		tool_name += ".gd"
		
	var skill_path = "res://ai_skills/".path_join(skill_name)
	if not DirAccess.dir_exists_absolute(skill_path):
		# Fallback to addons path if it's a builtin skill being modified (though generally avoid this)
		skill_path = "res://addons/ai_assistant/skills/".path_join(skill_name)
		if not DirAccess.dir_exists_absolute(skill_path):
			return "Error: Skill '%s' not found." % skill_name
			
	var tools_path = skill_path.path_join("tools")
	if not DirAccess.dir_exists_absolute(tools_path):
		DirAccess.make_dir_recursive_absolute(tools_path)
		
	var full_path = tools_path.path_join(tool_name)
	var file = FileAccess.open(full_path, FileAccess.WRITE)
	if not file:
		return "Error: Could not create tool script at %s." % full_path
		
	file.store_string(script_content)
	file.close()
	
	# Refresh SkillManager to ensure the new tool is indexed
	var sm = load("res://addons/ai_assistant/skills/skill_manager.gd")
	sm.refresh_skills()
	
	return "Successfully added tool '%s' to skill '%s' at %s." % [tool_name, skill_name, full_path]
