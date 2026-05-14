## CreateSkillResourceTool - Tool to create a new skill directory and SKILL.md.

class_name CreateSkillResourceTool
extends AITool

func _init():
	super("create_skill_resource", "Creates the base folder and SKILL.md for a new AI skill.")


func get_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"name": { 
				"type": "string", 
				"description": "The slug-style name of the skill (e.g. 'godot-vfx')." 
			},
			"instructions": {
				"type": "string",
				"description": "The complete content for the SKILL.md file."
			}
		},
		"required": ["name", "instructions"]
	}


func execute(arguments: Dictionary) -> String:
	var name = arguments.get("name", "").to_lower().replace(" ", "-")
	var instructions = arguments.get("instructions", "")
	
	if name.is_empty():
		return "Error: Skill name is empty."
		
	var skill_path = "res://ai_skills/".path_join(name)
	if not DirAccess.dir_exists_absolute(skill_path):
		var err = DirAccess.make_dir_recursive_absolute(skill_path)
		if err != OK:
			return "Error: Could not create skill directory at %s (code %d)." % [skill_path, err]
			
	var md_path = skill_path.path_join("SKILL.md")
	var file = FileAccess.open(md_path, FileAccess.WRITE)
	if not file:
		return "Error: Could not create SKILL.md at %s." % md_path
		
	file.store_string(instructions)
	file.close()
	
	# Create tools directory as well
	var tools_path = skill_path.path_join("tools")
	DirAccess.make_dir_recursive_absolute(tools_path)
	
	# Refresh SkillManager so the new skill is discoverable immediately
	var sm = load("res://addons/ai_assistant/skills/skill_manager.gd")
	sm.refresh_skills()
	
	return "Successfully created skill resource at %s. Don't forget to add tools if needed!" % skill_path
