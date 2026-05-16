## SkillCreatorNode - An AISkill node that allows the AI to create other skills.

@tool
extends "res://addons/ai_assistant/skills/ai_skill_node.gd"

func _init() -> void:
	description = "Allows the AI to autonomously create new specialized AISkill nodes."
	definition = """You are an expert at creating specialized AI skills.
Use 'create_skill_node' to add a new AISkill node to the scene tree.
This new node will be added as a child of the node you are currently attached to.

When creating a skill:
1. Provide a clear, unique name.
2. Provide a concise description for discovery.
3. Provide detailed expert instructions in the 'definition' field.
4. (Optional) Provide 'script_content' for the logic. It MUST extend "res://addons/ai_assistant/skills/ai_skill_node.gd".
5. (Optional) Provide 'tools' array of JSON schemas matching the methods in 'script_content'.
"""
	tools = [
		{
			"type": "function",
			"function": {
				"name": "create_skill_node",
				"description": "Creates a new AISkill node as a child of the assistant node.",
				"parameters": {
					"type": "object",
					"properties": {
						"name": { 
							"type": "string", 
							"description": "The name of the new skill node." 
						},
						"description": { 
							"type": "string", 
							"description": "Brief description of the skill." 
						},
						"definition": { 
							"type": "string", 
							"description": "The detailed expert instructions for the skill." 
						},
						"script_content": {
							"type": "string",
							"description": "GDScript code for the skill node. Must extend 'res://addons/ai_assistant/skills/ai_skill_node.gd'."
						},
						"tools": {
							"type": "array",
							"items": { "type": "object" },
							"description": "Array of OpenAI tool schemas for the methods in script_content."
						}
					},
					"required": ["name", "description", "definition"]
				}
			}
		}
	]


func create_skill_node(arguments: Dictionary) -> String:
	var skill_name = arguments.get("name", "NewSkill")
	var skill_desc = arguments.get("description", "")
	var skill_def = arguments.get("definition", "")
	var script_content = arguments.get("script_content", "")
	var skill_tools = arguments.get("tools", [])
	
	var parent = get_parent()
	if not parent:
		return "Error: SkillCreatorNode has no parent to attach new skill to."
		
	# 1. Validate script if provided
	var script: GDScript = null
	if not script_content.is_empty():
		var ScriptExecutor = load("res://addons/ai_assistant/generator/script_executor.gd")
		var validation = ScriptExecutor.validate_gdscript_code(script_content, "res://addons/ai_assistant/skills/ai_skill_node.gd")
		if validation.error != null:
			return "Error: Script validation failed:\n" + validation.error
			
		# Save script to file for persistence
		var dir = "res://ai_skills/scripts/"
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)
			
		var script_path = dir.path_join(skill_name.to_lower().replace(" ", "_") + ".gd")
		var file = FileAccess.open(script_path, FileAccess.WRITE)
		if not file:
			return "Error: Could not save script to " + script_path
		file.store_string(ScriptExecutor.extract_code(script_content))
		file.close()
		
		script = load(script_path)
		if not script:
			return "Error: Failed to load the saved script from " + script_path

	# 2. Create the node
	var AISkillNodeScript = load("res://addons/ai_assistant/skills/ai_skill_node.gd")
	var new_skill = Node.new()
	if script:
		new_skill.set_script(script)
	else:
		new_skill.set_script(AISkillNodeScript)
		
	new_skill.name = skill_name
	new_skill.set("description", skill_desc)
	new_skill.set("definition", skill_def)
	
	var typed_tools: Array[Dictionary] = []
	for t in skill_tools:
		typed_tools.append(t)
	new_skill.set("tools", typed_tools)
	
	parent.add_child(new_skill)
	if Engine.is_editor_hint() and parent.owner:
		new_skill.owner = parent.owner
		
	return "Successfully created AISkill node '%s' as a child of '%s'%s." % [
		skill_name, 
		parent.name, 
		" with custom script" if script else ""
	]
