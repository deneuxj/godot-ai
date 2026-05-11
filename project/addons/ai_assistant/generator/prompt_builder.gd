## PromptBuilder - Constructs AI prompt from user input and texture attachments.
##
## Builds the [param messages] array passed to [class AIClient.chat()],
## including system prompt, user content, and optional multimodal (image) content.
## Also provides [method build_error_correction] for the error-correction loop.

class_name PromptBuilder

const AISettings = preload("res://addons/ai_assistant/settings/ai_settings.gd")


## System prompt for generating GDScripts that construct a node hierarchy.
const SCRIPTED_SCENE_SYSTEM_PROMPT := """\
You are a Godot 4 scene builder assistant.
Given a user prompt and optional visual references,
output a GDScript that constructs a 3D scene hierarchy.

Rules:
- Output valid GDScript code. You MAY use markdown code blocks (```gdscript ... ```).
- Your script MUST implement a `build() -> Node3D` method that returns the root of the constructed hierarchy.
- The script should NOT have an `extends` clause (it will be RefCounted by default) or it MAY `extends RefCounted`.
- Use standard Godot 4 nodes: Node3D, MeshInstance3D, OmniLight3D, etc.
- GDScript in Godot 4 DOES NOT support nested functions. Define all your logic in top-level functions (e.g., `build()`).
- Do NOT output any explanation unless it's outside the code block.

Tool Usage:
- You HAVE access to tools to explore Godot documentation and project resources.
- If you are unsure about a node's properties or methods, USE `explore_godot_docs`.
- If you need to check if a specific resource (mesh, texture, scene) exists or what it contains, USE `explore_project_resources`.
- If you need to modify an existing file or create a new one, USE `modify_project_resource`.
- If you need to verify if a file has errors (parse errors, load errors, missing dependencies), USE `validate_project_resource`.
- If you need to execute arbitrary GDScript or construct a scene hierarchy in the live tree, USE `execute_script`.
- DO NOT guess property names or resource paths. Verify them using tools first.

Example:
```gdscript
static func execute(node: Node):
	var mesh_node = MeshInstance3D.new()
	mesh_node.name = "Cube"
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1, 1, 1)
	mesh_node.mesh = mesh

	node.add_child(mesh_node)
	
	# CRITICAL: If running in the editor, set the owner so the node is saved and visible in the Scene dock.
	if Engine.is_editor_hint():
		mesh_node.owner = node.get_tree().edited_scene_root
```
"""

## System prompt for generating Godot .gd scripts.
const NODE_SCRIPT_SYSTEM_PROMPT := """\
You are a Godot 4 GDScript generator assistant.
Given a user prompt and optional visual references,
output a valid Godot 4 .gd script that extends Node3D.

Rules:
- Output valid GDScript code. You MAY use markdown code blocks (```gdscript ... ```).
- The script MUST `extends Node3D`.
- GDScript in Godot 4 DOES NOT support nested functions. Define all logic in class-level functions.
- Use Godot 4.x syntax.
- Implement `_ready()` or other lifecycle methods as requested.
- No explanation or extra text. Just the script content.

Tool Usage:
- You HAVE access to tools to explore Godot documentation and project resources.
- USE `explore_godot_docs` to verify class properties, methods, and signals before writing code.
- USE `explore_project_resources` to find existing assets or scripts in the project to avoid duplication or reference errors.
- USE `modify_project_resource` to surgically edit files or create new scripts.
- USE `validate_project_resource` to check your work or existing files for errors.
- Prefer using tools to gather information over making assumptions about the API or file structure.
"""

## Default system prompt for general Godot assistance in AIChat.
const CHAT_SYSTEM_PROMPT := """\
You are a helpful Godot Engine assistant.
You help users with GDScript, node organization, scene composition, and general engine features.

Tool Usage:
- You HAVE access to tools to explore Godot documentation and project resources.
- Use `explore_godot_docs` to provide technically accurate information about classes, methods, and properties.
- Use `explore_project_resources` to understand the project structure and help the user with their specific files.
- Use `modify_project_resource` to help the user by creating or editing files directly when requested.
- Use `validate_project_resource` to check if scripts or resources have errors and help fix them.
- When the user asks for code, ensure it follows Godot 4 conventions.

Formatting:
- ALWAYS use Godot's BBCode for formatting your responses.
- Use [b]bold[/b], [i]italic[/i], and [color=...]...[/color] for emphasis.
- Use [code]...[/code] for inline code and [codeblock]...[/codeblock] for larger code snippets.
- Use [url]...[/url] for links.
- DO NOT use Markdown formatting (like **bold** or `code`).
"""


## System prompt for routing requests between Analyst and Technician models.
const ROUTER_SYSTEM_PROMPT := """\
Analyze the user's latest request and categorize it into one of two workloads:

1. analyst: The request is complex, involves high-level reasoning, architectural planning, or multi-step strategy. Use this for "how should I structure..." or "design a system for..." type questions.
2. technician: The request is straightforward, involves implementing a specific feature, writing code for a known task, or using tools to perform project operations. Use this for "write a script that..." or "list the files in..." type questions. Also, use this for any request to FIX errors, debug code, or iterate on a previous implementation.

Respond with ONLY the word "analyst" or "technician". No other text.
"""


## Main entry point to build the AI conversation history.
static func build(prompt: String, textures: Array[Texture2D], mode: int) -> Array[Dictionary]:
	var messages: Array[Dictionary] = []
	
	# 1. System Prompt
	messages.append({
		"role": "system",
		"content": _get_system_prompt(mode)
	})
	
	# 2. User Message
	var user_content: Array[Dictionary] = []
	
	# Add text
	user_content.append({
		"type": "text",
		"text": prompt
	})
	
	# Add images if supported by the model (multimodal)
	for tex in textures:
		var base64 = _encode_texture(tex)
		if base64 != "":
			user_content.append({
				"type": "image_url",
				"image_url": {
					"url": "data:image/png;base64," + base64
				}
			})
			
	messages.append({
		"role": "user",
		"content": user_content
	})
	
	return messages


## Build the tools array based on node configuration.
static func get_tool_definitions(enable_docs: bool, enable_resources: bool, enable_modify: bool = false, enable_validate: bool = false, enable_execute: bool = false) -> Array[Dictionary]:
	var tools: Array[Dictionary] = []
	
	if enable_docs:
		var tool = load("res://addons/ai_assistant/tools/godot_docs_tool.gd").new()
		tools.append(tool.get_definition())
	
	if enable_resources:
		var tool = load("res://addons/ai_assistant/tools/project_resources_tool.gd").new()
		tools.append(tool.get_definition())
		
	if enable_modify:
		var tool = load("res://addons/ai_assistant/tools/modify_project_resource_tool.gd").new()
		tools.append(tool.get_definition())
	
	if enable_validate:
		var tool = load("res://addons/ai_assistant/tools/validate_project_resource_tool.gd").new()
		tools.append(tool.get_definition())
		
	if enable_execute:
		var tool = load("res://addons/ai_assistant/tools/execute_script_tool.gd").new()
		tools.append(tool.get_definition())
		
	return tools


## Encode a [Texture2D] to base64 PNG string.
static func _encode_texture(texture: Texture2D) -> String:
	if not texture:
		return ""
	
	var img := _texture_to_image(texture)
	if not img:
		return ""
		
	var buffer := img.save_png_to_buffer()
	return Marshalls.raw_to_base64(buffer)


## Convert a [Texture2D] to an [Image] for base64 encoding.
static func _texture_to_image(texture: Texture2D) -> Image:
	if texture is ImageTexture or texture is CompressedTexture2D:
		return texture.get_image()

	# Fallback: try to get the underlying image data
	var img_resource: Variant = texture.get("resource")
	if img_resource is Image:
		return img_resource as Image

	return null


## Get the system prompt, checking the project setting override first.
static func _get_system_prompt(mode: int) -> String:
	var custom: String = AISettings.get_string(AISettings.GEN, "system_prompt")
	if custom != "":
		return custom
	
	# Enum mapping (must match AIAgentAssisted3D.GenerationMode)
	if mode == 0: # SCRIPTED_SCENE
		return SCRIPTED_SCENE_SYSTEM_PROMPT
	else: # NODE_SCRIPT
		return NODE_SCRIPT_SYSTEM_PROMPT


## Append error details to the conversation history for the error-correction loop.
static func build_error_correction(messages: Array[Dictionary], error_result: Dictionary, last_content: String) -> Array[Dictionary]:
	# Add the AI's previous (erroneous) response as an assistant message.
	messages.append({
		"role": "assistant",
		"content": last_content
	})
	
	# Add the error details as a new user message.
	var error_msg := "The generated output failed validation with the following error:\n\n%s" % error_result.error
	
	messages.append({
		"role": "user",
		"content": error_msg
	})
	
	return messages
