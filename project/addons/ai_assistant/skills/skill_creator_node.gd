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
4. (Optional) You can later use 'modify_project_resource' or 'execute_script' to add specific tools/methods to the generated node's script.
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
	
	var parent = get_parent()
	if not parent:
		return "Error: SkillCreatorNode has no parent to attach new skill to."
		
	var AISkillNodeScript = preload("res://addons/ai_assistant/skills/ai_skill_node.gd")
	var new_skill = AISkillNodeScript.new()
	new_skill.name = skill_name
	new_skill.description = skill_desc
	new_skill.definition = skill_def
	
	parent.add_child(new_skill)
	if Engine.is_editor_hint() and parent.owner:
		new_skill.owner = parent.owner
		
	return "Successfully created AISkill node '%s' as a child of '%s'." % [skill_name, parent.name]
