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

GDScript 2.0 Best Practices:
- When using functions like get(), load(), or Dictionary.get(), always provide an explicit static type (e.g., `var x: int = ...`) instead of using inference (`:=`).
- Prefer explicit typing for all variable declarations and function signatures.

Tool Usage:
- You HAVE access to tools to explore Godot documentation and project resources.
- If you are unsure about a node's properties or methods, USE `explore_godot_docs`.
- If you need to check if a specific resource (mesh, texture, scene) exists or what it contains, USE `explore_project_resources`.
- If you need to navigate the scene tree or inspect properties of nodes in the live scene, USE `explore_node_hierarchy`.
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
	# The 'node' (AIChat) owner is typically the root of the scene.
	if node.owner:
		mesh_node.owner = node.owner
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

GDScript 2.0 Best Practices:
- When using functions like get(), load(), or Dictionary.get(), always provide an explicit static type (e.g., `var x: int = ...`) instead of using inference (`:=`).
- Prefer explicit typing for all variable declarations and function signatures.

Tool Usage:
- You HAVE access to tools to explore Godot documentation and project resources.
- USE `explore_godot_docs` to verify class properties, methods, and signals before writing code.
- USE `explore_project_resources` to find existing assets or scripts in the project to avoid duplication or reference errors.
- USE `explore_node_hierarchy` to inspect the live scene tree and node properties relative to the assistant.
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
- Use `explore_node_hierarchy` to navigate the scene tree and inspect live node properties.
- Use `modify_project_resource` to help the user by creating or editing files directly when requested.
- Use `validate_project_resource` to check if scripts or resources have errors and help fix them.
- When the user asks for code, ensure it follows Godot 4 conventions.

GDScript 2.0 Best Practices:
- When fixing "typed as Variant" errors (common with functions like get(), load(), or Dictionary.get()), always provide an explicit static type (e.g., [code]var x: int = ...[/code]) instead of using inference ([code]:=[/code]).
- Prefer explicit typing for all variable declarations and function signatures.

Surgical Editing Rules:
- When using [code]modify_project_resource[/code], you MUST provide the [code]old_content[/code] parameter with the exact text you intend to replace. This ensures a safe match.
- If a modification fails to fix an error reported by [code]validate_project_resource[/code], DO NOT guess. Use [code]explore_project_resources[/code] with [code]start_line[/code] and [code]end_line[/code] to read the actual file content and verify the state of the file before retrying.

CRITICAL: Tool Calling Format
- You MUST use the standard JSON tool calling format.
- DO NOT use XML tags like <tool_call> or <function>.
- Your response should contain ONLY the tool call block if you need to use a tool.

Continuation Rule:
- After calling a tool and receiving its result, you MUST provide a final text response to the user.
- Summarize the actions taken and the results obtained.
- Do not stop the conversation until you have confirmed the results with the user.

Formatting:
- ALWAYS use Godot's BBCode for formatting your responses.
- Use [b]bold[/b], [i]italic[/i], and [color=...]...[/color] for emphasis.
- Use [code]...[/code] for inline code and [codeblock]...[/codeblock] for larger code snippets.
- Use [url]...[/url] for links.
- DO NOT use Markdown formatting (like **bold** or `code`).
"""


## System prompt for Analyst model (complex planning).
const ANALYST_SYSTEM_PROMPT := """\
You are a Godot 4 Architectural Analyst.
Your goal is to understand complex user requests and design a robust implementation plan.

Rules:
1. Analyze the request and the current project context.
2. Provide a step-by-step implementation plan.
3. DO NOT implement the code or call tools that modify the project.
4. End your response by asking the user if they want to proceed with this plan.

The goal is to allow a Technician model to handle the actual implementation once the plan is approved.

Formatting:
- ALWAYS use Godot's BBCode for formatting your responses.
- Use [b]bold[/b], [i]italic[/i], and [color=...]...[/color] for emphasis.
- Use [code]...[/code] for inline code and [codeblock]...[/codeblock] for larger code snippets.
- Use [url]...[/url] for links.
- DO NOT use Markdown formatting (like **bold** or `code`).
"""


## System prompt for Technician model (implementation and tool use).
const TECHNICIAN_SYSTEM_PROMPT := """\
You are a Godot 4 Implementation Technician.
Your goal is to execute specific technical tasks and tool calls.

Rules:
1. Perform the requested implementation or tool calls as efficiently as possible.
2. After calling a tool and receiving its result, you MUST provide a final text response to the user summarizing exactly what was done.
3. If you encounter an insurmountable obstacle or fail at the task, explicitly state "FAILED" and describe the specific error or blocker.

GDScript 2.0 Best Practices:
- When fixing "typed as Variant" errors (common with functions like get(), load(), or Dictionary.get()), always provide an explicit static type (e.g., [code]var x: int = ...[/code]) instead of using inference ([code]:=[/code]).
- Prefer explicit typing for all variable declarations and function signatures.

Surgical Editing Rules:
- When using [code]modify_project_resource[/code], you MUST provide the [code]old_content[/code] parameter with the exact text you intend to replace. This ensures a safe match.
- If a modification fails to fix an error reported by [code]validate_project_resource[/code], DO NOT guess. Use [code]explore_project_resources[/code] with [code]start_line[/code] and [code]end_line[/code] to read the actual file content and verify the state of the file before retrying.

CRITICAL: Tool Calling Format
- You MUST use the standard JSON tool calling format.
- DO NOT use XML tags like <tool_call> or <function>.

Formatting:
- ALWAYS use Godot's BBCode for formatting your responses.
- Use [b]bold[/b], [i]italic[/i], and [color=...]...[/color] for emphasis.
- Use [code]...[/code] for inline code and [codeblock]...[/codeblock] for larger code snippets.
- Use [url]...[/url] for links.
- DO NOT use Markdown formatting (like **bold** or `code`).
"""


## System prompt for routing requests between Analyst and Technician models.
const ROUTER_SYSTEM_PROMPT := """\
You are a workload classifier. Your job is to categorize the user's latest request and decide if high reasoning effort is needed.

1. analyst: The request is complex, involves high-level reasoning, architectural planning, or multi-step strategy. Use this for "how should I structure..." or "design a system for..." type questions.
2. technician: The request is straightforward, involves implementing a specific feature, writing code for a known task, or using tools to perform project operations. Use this for "write a script that..." or "list the files in..." type questions. Also, use this for any request to FIX errors, debug code, or iterate on a previous implementation.

Thinking Effort:
If the request involves deep logical thinking, complex mathematics, or abstract problem-solving that would benefit from high reasoning effort, append ":on" to your answer.

Respond with ONLY: "analyst", "analyst:on", "technician", or "technician:on". No other text.
"""


## Get the system prompt for generic chat, following the hierarchy:
## 1. Explicit override
## 2. Project setting override (if not empty)
## 3. Hardcoded CHAT_SYSTEM_PROMPT constant
static func get_chat_prompt(override: String = "") -> String:
	if not override.is_empty():
		return override
	
	var setting = AISettings.get_string(AISettings.GEN, "system_prompt")
	if not setting.is_empty():
		return setting
		
	return CHAT_SYSTEM_PROMPT


## Get the system prompt for routing, following the hierarchy:
## 1. Explicit override
## 2. Project setting override (if not empty)
## 3. Hardcoded ROUTER_SYSTEM_PROMPT constant
static func get_router_prompt(override: String = "") -> String:
	if not override.is_empty():
		return override
	
	var setting = AISettings.get_string(AISettings.GEN, "router_system_prompt")
	if not setting.is_empty():
		return setting
		
	return ROUTER_SYSTEM_PROMPT


## Get the system prompt for analyst mode, following the hierarchy:
## 1. Explicit override
## 2. Project setting override (if not empty)
## 3. Hardcoded ANALYST_SYSTEM_PROMPT constant
static func get_analyst_prompt(override: String = "") -> String:
	if not override.is_empty():
		return override
	
	var setting = AISettings.get_string(AISettings.GEN, "analyst_system_prompt")
	if not setting.is_empty():
		return setting
		
	return ANALYST_SYSTEM_PROMPT


## Get the system prompt for technician mode, following the hierarchy:
## 1. Explicit override
## 2. Project setting override (if not empty)
## 3. Hardcoded TECHNICIAN_SYSTEM_PROMPT constant
static func get_technician_prompt(override: String = "") -> String:
	if not override.is_empty():
		return override
	
	var setting = AISettings.get_string(AISettings.GEN, "technician_system_prompt")
	if not setting.is_empty():
		return setting
		
	return TECHNICIAN_SYSTEM_PROMPT


## Main entry point to build the AI conversation history.
static func build(prompt: String, textures: Array[Texture2D], mode: int, discovered_skills: Array[Dictionary] = []) -> Array[Dictionary]:
	var messages: Array[Dictionary] = []
	
	# 1. System Prompt
	messages.append({
		"role": "system",
		"content": _get_system_prompt(mode, discovered_skills)
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
static func get_tool_definitions(enable_docs: bool, enable_resources: bool, enable_modify: bool = false, enable_validate: bool = false, enable_execute: bool = false, enable_capture: bool = false, enable_hierarchy: bool = false) -> Array[Dictionary]:
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
	
	if enable_capture:
		var tool = load("res://addons/ai_assistant/tools/capture_editor_view_tool.gd").new()
		tools.append(tool.get_definition())
	
	if enable_hierarchy:
		var tool = load("res://addons/ai_assistant/tools/explore_node_hierarchy_tool.gd").new()
		tools.append(tool.get_definition())
	
	# Always include activate_skill if skills are supported/enabled
	var activate_tool = load("res://addons/ai_assistant/tools/activate_skill_tool.gd").new()
	tools.append(activate_tool.get_definition())
		
	return tools


## Returns a string listing available skills for the discovery phase.
## [param discovered_skills] is an array of Dictionaries: {"name": String, "description": String}
static func get_skills_discovery_context(discovered_skills: Array[Dictionary]) -> String:
	if discovered_skills.is_empty():
		return ""
		
	var lines: Array[String] = ["\n\nAVAILABLE SKILLS:"]
	lines.append("You have access to specialized skills. Only their descriptions are shown here.")
	lines.append("Use `activate_skill(name)` to load a skill's full instructions and tools.")
	
	for skill in discovered_skills:
		lines.append("- %s: %s" % [skill["name"], skill["description"]])
		
	return "\n".join(lines)


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
static func _get_system_prompt(mode: int, discovered_skills: Array[Dictionary] = []) -> String:
	var custom: String = AISettings.get_string(AISettings.GEN, "system_prompt")
	var base_prompt := ""
	
	if custom != "":
		base_prompt = custom
	else:
		# Enum mapping (must match AIAgentAssisted3D.GenerationMode)
		if mode == 0: # SCRIPTED_SCENE
			base_prompt = SCRIPTED_SCENE_SYSTEM_PROMPT
		else: # NODE_SCRIPT
			base_prompt = NODE_SCRIPT_SYSTEM_PROMPT
			
	var env_context := get_environment_context()
	var skills_context := get_skills_discovery_context(discovered_skills)
	
	return base_prompt + env_context + skills_context


## Returns a string describing the current execution environment.
static func get_environment_context() -> String:
	return "\n\nENVIRONMENT: You are currently running within the Godot Editor. You have access to Editor-only APIs and the edited scene tree." if Engine.is_editor_hint() else "\n\nENVIRONMENT: You are currently running in the Game/Runtime. Editor-only APIs are NOT available."


## Append error details to the conversation history for the error-correction loop.
static func build_error_correction(messages: Array[Dictionary], error_result: Dictionary, last_content: String) -> Array[Dictionary]:
# ... (rest of method code)
	return messages


## Sanitizes a conversation history to ensure strict role alternation and valid tool transactions.
## Useful for models with strict Jinja templates (Mistral, Llama 3).
static func sanitize_history(messages: Array[Dictionary]) -> Array[Dictionary]:
	if messages.is_empty():
		return []
		
	var sanitized: Array[Dictionary] = []
	
	# 1. Ensure the first message is system or user.
	# (Mistral usually accepts System as the very first message).
	var start_idx = 0
	if messages[0].role == "system":
		sanitized.append(messages[0].duplicate())
		start_idx = 1
	
	for i in range(start_idx, messages.size()):
		var msg = messages[i].duplicate()
		var last = sanitized.back() if not sanitized.is_empty() else null
		
		if not last:
			sanitized.append(msg)
			continue
			
		# Case A: Sequential messages of the same role
		if msg.role == last.role and msg.role != "tool":
			# Merge text content if possible
			if typeof(last.content) == TYPE_STRING and typeof(msg.content) == TYPE_STRING:
				last.content += "\n\n" + msg.content
				continue
			# If content types differ or contain tool_calls, we might have to just insert a dummy role 
			# but merging is safer for text.
		
		# Case B: Tool message follows a Tool message (allowed for batch results)
		if msg.role == "tool" and last.role == "tool":
			sanitized.append(msg)
			continue
			
		# Case C: User message follows a Tool message (ILLEGAL in Mistral)
		if msg.role == "user" and last.role == "tool":
			# Insert dummy assistant message to close the transaction
			sanitized.append({"role": "assistant", "content": "..."})
			sanitized.append(msg)
			continue
			
		# Case D: Role is the same as last (and not tool) - this should have been caught by Case A 
		# but if merging failed or roles are user-user:
		if msg.role == last.role:
			if msg.role == "user":
				sanitized.append({"role": "assistant", "content": "..."})
			else:
				sanitized.append({"role": "user", "content": "..."})
		
		sanitized.append(msg)
		
	return sanitized
