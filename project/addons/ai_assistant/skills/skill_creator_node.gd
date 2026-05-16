## SkillCreatorNode - An AISkill node that allows the AI to create other skills.

@tool
class_name SkillCreatorNode
extends "res://addons/ai_assistant/skills/ai_skill_node.gd"

func _init() -> void:
	description = "Allows the AI to autonomously create new specialized AISkill nodes from scripts."
	definition = """You are an expert at creating specialized AI skills.
To create a new skill, follow this two-step workflow:

1. **Write the Script**: Use 'modify_project_resource' to create a new script file in 'res://ai_skills/scripts/'.
   The script MUST follow this template:
   ```gdscript
   @tool
   extends \"res://addons/ai_assistant/skills/ai_skill_node.gd\"

   func _init() -> void:
       description = \"Brief summary for discovery.\"
       definition = \"Detailed expert instructions for your tools.\"
       tools = [
           {
               \"type\": \"function\",
               \"function\": {
                   \"name\": \"my_tool_name\",
                   \"description\": \"...\",
                   \"parameters\": { \"type\": \"object\", \"properties\": { ... } }
               }
           }
       ]

   func my_tool_name(arguments: Dictionary) -> String:
       # Your logic here
       return \"Success message\"
   ```

2. **Instantiate the Node**: Use 'create_skill_node' with the path to the script you just created.
   This will add the AISkillNode to the scene tree.
"""
	tools = [
		{
			"type": "function",
			"function": {
				"name": "create_skill_node",
				"description": "Instantiates a new AISkill node from an existing script file.",
				"parameters": {
					"type": "object",
					"properties": {
						"name": { 
							"type": "string", 
							"description": "The name for the new skill node in the scene tree." 
						},
						"script_path": { 
							"type": "string", 
							"description": "The res:// path to the GDScript file created in step 1." 
						}
					},
					"required": ["name", "script_path"]
				}
			}
		}
	]


func create_skill_node(arguments: Dictionary) -> String:
	var skill_name = arguments.get("name", "NewSkill")
	var script_path = arguments.get("script_path", "")
	
	if script_path.is_empty():
		return "Error: No script_path provided."
		
	if not script_path.begins_with("res://"):
		script_path = "res://" + script_path

	var parent = get_parent()
	if not parent:
		return "Error: SkillCreatorNode has no parent to attach new skill to."
		
	# 1. Validate script path exists
	if not FileAccess.file_exists(script_path):
		return "Error: Script file not found at " + script_path
		
	# 2. Load and validate the script
	var script = load(script_path)
	if not script:
		return "Error: Failed to load script at " + script_path
		
	var ScriptExecutor = load("res://addons/ai_assistant/generator/script_executor.gd")
	var validation = ScriptExecutor.validate_gdscript_code(script.source_code, "res://addons/ai_assistant/skills/ai_skill_node.gd")
	if validation.error != null:
		return "Error: Script at %s is invalid:\n%s" % [script_path, validation.error]

	# 3. Create the node
	var new_skill = Node.new()
	new_skill.set_script(script)
	new_skill.name = skill_name
	
	parent.add_child(new_skill)
	if Engine.is_editor_hint() and parent.owner:
		new_skill.owner = parent.owner
		
	return "Successfully created AISkill node '%s' as a child of '%s' using script '%s'." % [
		skill_name, 
		parent.name, 
		script_path
	]
