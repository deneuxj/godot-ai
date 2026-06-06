## PromptBuilder - Constructs AI prompt from user input and texture attachments.
##
## Builds the [param messages] array passed to [class AIClient.chat()],
## including system prompt, user content, and optional multimodal (image) content.
## Also provides [method build_error_correction] for the error-correction loop.

class_name PromptBuilder

const AISettings = preload("res://addons/ai_assistant/settings/ai_settings.gd")


# --- System Prompt Providers (OO Architecture) ---

## Base class for objects that can dynamically build a system prompt.
class SystemPromptProvider extends RefCounted:
	## Returns the full system prompt string, optionally injected with turn info.
	func get_system_prompt(_remaining_turns: int = -1) -> String:
		return ""


## Provider for simple, static system prompts (e.g. classification, routing).
class SimpleProvider extends SystemPromptProvider:
	var base_prompt: String = ""
	
	func _init(p_prompt: String) -> void:
		base_prompt = p_prompt
		
	func get_system_prompt(remaining_turns: int = -1) -> String:
		if remaining_turns >= 0:
			return PromptBuilder.inject_turn_info(base_prompt, remaining_turns)
		return base_prompt


## Provider for dynamic chat prompts that include project context.
class ChatProvider extends SystemPromptProvider:
	var chat_node: Node # AIChat
	
	func _init(p_node: Node) -> void:
		chat_node = p_node
		
	func get_system_prompt(remaining_turns: int = -1) -> String:
		if not is_instance_valid(chat_node):
			return ""
			
		var active_prompt = chat_node.get("active_system_prompt")
		var todo_list = chat_node.get("todo_list")
		var discovered_skills = chat_node.call("_discover_active_skills")
		var memory = ""
		if "memory" in chat_node:
			memory = chat_node.get("memory")
		
		var base = PromptBuilder.get_chat_prompt(active_prompt)
		var env = PromptBuilder.get_environment_context()
		var mem = PromptBuilder.get_memory_context(memory)
		var skills = PromptBuilder.get_skills_discovery_context(discovered_skills)
		var todos = PromptBuilder._get_todo_context(todo_list)
		
		var final_prompt = base + env + mem + skills + todos
		if remaining_turns >= 0:
			final_prompt = PromptBuilder.inject_turn_info(final_prompt, remaining_turns)
		return final_prompt


## Provider for dynamic scene/script generation prompts.
class SceneBuilderProvider extends SystemPromptProvider:
	var builder_node: Node # AIAgentAssisted3D
	
	func _init(p_node: Node) -> void:
		builder_node = p_node
		
	func get_system_prompt(remaining_turns: int = -1) -> String:
		if not is_instance_valid(builder_node):
			return ""
			
		var mode = builder_node.get("generation_mode")
		var todo_list = builder_node.get("todo_list")
		var discovered_skills = builder_node.call("_discover_active_skills")
		
		return PromptBuilder._get_system_prompt(mode, discovered_skills, todo_list, remaining_turns)


# --- Factory Methods ---

static func create_simple_provider(prompt: String) -> SimpleProvider:
	return SimpleProvider.new(prompt)

static func create_chat_provider(chat_node: Node) -> ChatProvider:
	return ChatProvider.new(chat_node)

static func create_scene_builder_provider(builder_node: Node) -> SceneBuilderProvider:
	return SceneBuilderProvider.new(builder_node)


# --- Constants & Static Helpers ---

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

Efficiency and Limits:
- You have {REMAINING_TURNS} tool calls left in this turn. 
- Minimize turns by being direct: use `search` or `list_files` with specific paths instead of navigating folders one level at a time.
- Batch your investigations: if you need to read multiple files, do so as quickly as possible without intermediate "ready to proceed" messages.
- If you run out of tool calls and need more, state "NEED_MORE_TURNS" and describe what is left to do.

GDScript 2.0 Best Practices:
- When using functions like get(), load(), or Dictionary.get(), always provide an explicit static type (e.g., `var x: int = ...`) instead of using inference (`:=`).
- Prefer explicit typing for all variable declarations and function signatures.

Tool Usage:
- You HAVE access to tools to explore Godot documentation and project resources.
- If you are unsure about a node's properties or methods, USE `explore_godot_docs`.
- If you need to check if a specific resource (mesh, texture, scene) exists or what it contains, USE `explore_project_resources`.
- If you need to navigate the scene tree or inspect properties of nodes in the live scene, USE `explore_node_hierarchy`.
- If you need to manage tasks and track progress, USE `manage_todo_list`.
- If you need to modify an existing file or create a new one, USE `modify_project_resource`.
- If you need to verify if a file has errors (parse errors, load errors, missing dependencies), USE `validate_project_resource`.
- If you need to execute arbitrary GDScript or construct a scene hierarchy in the live tree, USE `execute_script`.
- DO NOT guess property names or resource paths. Verify them using tools first.
- As the harness and the tools are still under development, you MUST stop whenever you have difficulties using a tool, describe the problem to the user and ask for guidance.

Task Management:
- For complex requests, ALWAYS maintain a TODO list using `manage_todo_list`.
- Use `add` to append a new task.
- Use `update` to mark a task as done (e.g., `{"operation": "update", "index": 0, "done": true}`).
- Use `remove` to delete a task if it's no longer relevant.
- Use `clear` if the entire plan needs to be discarded.
- This helps you maintain focus and ensures you don't lose track of the goal.

Surgical Editing Rules:
- When using `modify_project_resource`, you MUST provide the `old_content` parameter with the exact text you intend to replace. This ensures a safe match.
- If a modification fails to fix an error reported by `validate_project_resource`, DO NOT guess. Use `explore_project_resources` with `start_line` and `end_line` to read the actual file content and verify the state of the file before retrying.

CRITICAL: Tool Calling Format
- You MUST use the standard JSON tool calling format.
- DO NOT use XML tags like <tool_call> or <function>.
- DO NOT write extensive plans, internal monologues, or debate your actions. Limit any pre-tool thought process to 1-2 concise sentences. Execute tool calls immediately.
- Your response should contain ONLY the tool call block if you need to use a tool.

Continuation Rule:
- After calling tools to gather information, you MUST provide the final GDScript code block as your final response.

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

Efficiency and Limits:
- You have {REMAINING_TURNS} tool calls left in this turn. 
- Minimize turns by being direct: use `search` or `list_files` with specific paths instead of navigating folders one level at a time.
- Batch your investigations: gather all required information before starting to write the script.
- If you run out of tool calls and need more, state "NEED_MORE_TURNS" and describe what is left to do.

GDScript 2.0 Best Practices:
- When using functions like get(), load(), or Dictionary.get(), always provide an explicit static type (e.g., `var x: int = ...`) instead of using inference (`:=`).
- Prefer explicit typing for all variable declarations and function signatures.

Tool Usage:
- You HAVE access to tools to explore Godot documentation and project resources.
- USE `explore_godot_docs` to verify class properties, methods, and signals before writing code.
- USE `explore_project_resources` to find existing assets or scripts in the project to avoid duplication or reference errors.
- USE `explore_node_hierarchy` to inspect the live scene tree and node properties relative to the assistant.
- USE `manage_todo_list` to break down and track your progress on complex scripting tasks.
- USE `modify_project_resource` to surgically edit files or create new scripts.
- USE `validate_project_resource` to check your work or existing files for errors.
- Prefer using tools to gather information over making assumptions about the API or file structure.
- As the harness and the tools are still under development, you MUST stop whenever you have difficulties using a tool, describe the problem to the user and ask for guidance.

Task Management:
- For complex requests, ALWAYS maintain a TODO list using `manage_todo_list`.
- Use `add` to append a new task.
- Use `update` to mark a task as done (e.g., `{"operation": "update", "index": 0, "done": true}`).
- Use `remove` to delete a task if it's no longer relevant.
- Use `clear` if the entire plan needs to be discarded.
- This helps you maintain focus and ensures you don't lose track of the goal.

Surgical Editing Rules:
- When using `modify_project_resource`, you MUST provide the `old_content` parameter with the exact text you intend to replace. This ensures a safe match.
- If a modification fails to fix an error reported by `validate_project_resource`, DO NOT guess. Use `explore_project_resources` with `start_line` and `end_line` to read the actual file content and verify the state of the file before retrying.

CRITICAL: Tool Calling Format
- You MUST use the standard JSON tool calling format.
- DO NOT use XML tags like <tool_call> or <function>.
- DO NOT write extensive plans, internal monologues, or debate your actions. Limit any pre-tool thought process to 1-2 concise sentences. Execute tool calls immediately.
- Your response should contain ONLY the tool call block if you need to use a tool.

Continuation Rule:
- After calling tools to gather information, you MUST provide the final GDScript code block as your final response.
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
- Use `manage_todo_list` to maintain a list of tasks for complex user requests. Proactively create a TODO list to track your progress and mark tasks as done.
- Use `modify_project_resource` to help the user by creating or editing files directly when requested.
- Use `validate_project_resource` to check if scripts or resources have errors and help fix them.
- When the user asks for code, ensure it follows Godot 4 conventions.
- As the harness and the tools are still under development, you MUST stop whenever you have difficulties using a tool, describe the problem to the user and ask for guidance.

Efficiency and Limits:
- You have {REMAINING_TURNS} tool calls left in this turn. 
- Minimize turns by being direct: use `search` or `list_files` with specific paths instead of navigating folders one level at a time.
- Batch your investigations: gather all data (docs, files, hierarchy) in as few turns as possible to provide a comprehensive answer quickly.
- If you run out of tool calls and need more, state "NEED_MORE_TURNS" and describe what is left to do.

GDScript 2.0 Best Practices:
- When fixing "typed as Variant" errors (common with functions like get(), load(), or Dictionary.get()), always provide an explicit static type (e.g., [code]var x: int = ...[/code]) instead of using inference ([code]:=[/code]).
- Prefer explicit typing for all variable declarations and function signatures.

Task Management:
- Use `manage_todo_list` to stay organized with a flat list of tasks.
- `add` new tasks for sub-goals, `update` to track progress, and `remove` or `clear` when finished.
- ALWAYS maintain a clear list of what you are doing.
- STAY focused on the tasks in your list.

Surgical Editing Rules:
- When using [code]modify_project_resource[/code], you MUST provide the [code]old_content[/code] parameter with the exact text you intend to replace. This ensures a safe match.
- If a modification fails to fix an error reported by [code]validate_project_resource[/code], DO NOT guess. Use [code]explore_project_resources[/code] with [code]start_line[/code] and [code]end_line[/code] to read the actual file content and verify the state of the file before retrying.

CRITICAL: Tool Calling Format
- You MUST use the standard JSON tool calling format.
- DO NOT use XML tags like <tool_call> or <function>.
- DO NOT write extensive plans, internal monologues, or debate your actions. Limit any pre-tool thought process to 1-2 concise sentences. Execute tool calls immediately.
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
3. Suggest a TODO list structure using `manage_todo_list` that the Technician can use.
4. DO NOT implement the code or call tools that modify the project.
5. End your response by asking the user if they want to proceed with this plan.

The goal is to allow a Technician model to handle the actual implementation once the plan is approved.

Tool Usage & Task Management:
- Use `manage_todo_list` to maintain a list of tasks for the Technician. Proactively create a TODO list to track progress.
- Use `add` to append new tasks, `update` to track progress, and `remove` or `clear` when finished.
- As the harness and the tools are still under development, you MUST stop whenever you have difficulties using a tool, describe the problem to the user and ask for guidance.

Efficiency and Limits:
- You have {REMAINING_TURNS} tool calls left in this turn.
- If you run out of tool calls and need more, state "NEED_MORE_TURNS" and describe what is left to do.

CRITICAL: Tool Calling Format
- You MUST use the standard JSON tool calling format.
- DO NOT use XML tags like <tool_call> or <function>.
- DO NOT write extensive plans, internal monologues, or debate your actions. Limit any pre-tool thought process to 1-2 concise sentences. Execute tool calls immediately.
- Your response should contain ONLY the tool call block if you need to use a tool.

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
2. Use `manage_todo_list` to track your progress on a flat list.
3. `add` the Analyst's plan steps as tasks, `update` them as you go.
4. STAY focused on the current task.
5. After calling a tool and receiving its result, you MUST provide a final text response to the user summarizing exactly what was done.
6. If you encounter an insurmountable obstacle or fail at the task, explicitly state "FAILED" and describe the specific error or blocker.

Tool Usage:
- You HAVE access to tools to explore Godot documentation, project resources, and the live scene tree.
- USE `explore_node_hierarchy` to navigate the scene tree and find existing nodes (e.g. to locate where the walls are).
- USE `execute_script` to make modifications to the live scene, but only if you cannot achieve the result with specific tools.
- USE `explore_godot_docs` if you need to check API documentation.
- USE `explore_project_resources` to read existing files and assets, but DO NOT use it to parse `.tscn` files directly if you just need to find nodes in the live scene. Use `explore_node_hierarchy` for the live scene.
- As the harness and the tools are still under development, you MUST stop whenever you have difficulties using a tool, describe the problem to the user and ask for guidance.

Task Management:
- Use `manage_todo_list` to stay organized with a flat list of tasks.
- `add` new tasks for sub-goals, `update` to track progress, and `remove` or `clear` when finished.
- `add` the Analyst's plan steps as tasks, `update` them as you go.
- ALWAYS maintain a clear list of what you are doing.
- STAY focused on the tasks in your list.

Efficiency and Limits:
- You have {REMAINING_TURNS} tool calls left in this turn. 
- Minimize turns by being direct: use `search` or `list_files` with specific paths instead of navigating folders one level at a time.
- Batch your actions: perform as many tool calls as possible in a single response to complete the task efficiently.
- If you run out of tool calls and need more, state "NEED_MORE_TURNS" and describe what is left to do.

GDScript 2.0 Best Practices:
- When fixing "typed as Variant" errors (common with functions like get(), load(), or Dictionary.get()), always provide an explicit static type (e.g., [code]var x: int = ...[/code]) instead of using inference ([code]:=[/code]).
- Prefer explicit typing for all variable declarations and function signatures.

Surgical Editing Rules:
- When using [code]modify_project_resource[/code], you MUST provide the [code]old_content[/code] parameter with the exact text you intend to replace. This ensures a safe match.
- If a modification fails to fix an error reported by [code]validate_project_resource[/code], DO NOT guess. Use [code]explore_project_resources[/code] with [code]start_line[/code] and [code]end_line[/code] to read the actual file content and verify the state of the file before retrying.

CRITICAL: Tool Calling Format
- You MUST use the standard JSON tool calling format.
- DO NOT use XML tags like <tool_call> or <function>.
- DO NOT write extensive plans, internal monologues, or debate your actions. Limit any pre-tool thought process to 1-2 concise sentences. Execute tool calls immediately.

Formatting:
- ALWAYS use Godot's BBCode for formatting your responses.
- Use [b]bold[/b], [i]italic[/i], and [color=...]...[/color] for emphasis.
- Use [code]...[/code] for inline code and [codeblock]...[/codeblock] for larger code snippets.
- Use [url]...[/url] for links.
- DO NOT use Markdown formatting (like **bold** or `code`).
"""


## System prompt for routing requests between Analyst and Technician models.
const ROUTER_SYSTEM_PROMPT := """\
[SYSTEM: CLASSIFICATION MACHINE]
You are a binary classification algorithm. You are NOT an AI assistant.
Your ONLY function is to categorize the [LATEST_USER_REQUEST] in the provided transcript.

[RULES]
1. DO NOT fulfill the user's request.
2. DO NOT design anything.
3. DO NOT output JSON.
4. DO NOT explain your decision.
5. ONLY output one of the four valid strings.

[ROLES]
- analyst: User wants to "DESIGN", "PLAN", "STRUCTURE", or "RESEARCH" (Architectural/Abstract).
- technician: User wants to "IMPLEMENT", "WRITE CODE", "FIX", or "RUN" (Technical/Execution).

[THINKING]
Append ":on" (e.g., "analyst:on") if the request involves complex math or logic.

[EXAMPLES]
- user said: "Design a wall skill" -> analyst:on
- user said: "Fix my script" -> technician
- user said: "How should I structure my levels?" -> analyst

[OUTPUT]
Respond with EXACTLY one string: analyst, analyst:on, technician, or technician:on.
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
static func build(prompt: String, textures: Array[Texture2D], mode: int, discovered_skills: Array[Dictionary] = [], todo_list: Array[Dictionary] = []) -> Array[Dictionary]:
	var messages: Array[Dictionary] = []
	
	# 1. System Prompt
	messages.append({
		"role": "system",
		"content": _get_system_prompt(mode, discovered_skills, todo_list)
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
static func get_tool_definitions(enable_docs: bool, enable_resources: bool, enable_modify: bool = false, enable_validate: bool = false, enable_execute: bool = false, enable_capture: bool = false, enable_hierarchy: bool = false, enable_todo: bool = false) -> Array[Dictionary]:
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
	
	if enable_todo:
		var tool = load("res://addons/ai_assistant/tools/manage_todo_list_tool.gd").new()
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
		
	var lines: Array[String] = ["\n\n[SPECIALIZED SKILLS AVAILABLE]"]
	lines.append("The following specialized capabilities are available but NOT currently loaded.")
	lines.append("To use them, you MUST first call `activate_skill(\"SkillName\")`.")
	lines.append("This will grant you the expert instructions and specialized tools for that task.")
	
	for skill in discovered_skills:
		lines.append("- %s: %s" % [skill["name"], skill["description"]])
		
	lines.append("\n[IMPORTANT] Do NOT attempt to implement these specialized tasks using generic GDScript if a skill is available. Always prefer activating and using the skill.")
		
	return "\n".join(lines)


## Returns a string representing the persistent memory context.
static func get_memory_context(memory: String) -> String:
	if memory.is_empty():
		return ""
		
	var lines: Array[String] = ["\n\n[PERSISTENT MEMORY]"]
	lines.append(memory.strip_edges())
		
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
static func _get_system_prompt(mode: int, discovered_skills: Array[Dictionary] = [], todo_list: Array[Dictionary] = [], remaining_turns: int = -1) -> String:
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
	var todo_context := _get_todo_context(todo_list)
	
	var final_prompt = base_prompt + env_context + skills_context + todo_context
	
	if remaining_turns >= 0:
		final_prompt = inject_turn_info(final_prompt, remaining_turns)
		
	return final_prompt


## Replaces the {REMAINING_TURNS} placeholder with the actual value.
static func inject_turn_info(prompt: String, remaining: int) -> String:
	return prompt.replace("{REMAINING_TURNS}", str(remaining))


## Returns a string representing the current TODO list for inclusion in the prompt.
static func _get_todo_context(list: Array[Dictionary]) -> String:
	if list.is_empty():
		return ""
		
	var lines: Array[String] = ["\n\nCURRENT TODO LIST:"]
	for i in range(list.size()):
		var task = list[i]
		var status = "[x]" if task.done else "[ ]"
		lines.append("%d. %s %s" % [i, status, task.text])
	
	return "\n".join(lines)


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
			var last_content = last.get("content")
			var msg_content = msg.get("content")
			# Merge text content if possible
			if typeof(last_content) == TYPE_STRING and typeof(msg_content) == TYPE_STRING:
				last.content = last_content + "\n\n" + msg_content
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
		
		# Case E: Dangling Tool Calls (CRITICAL)
		# If the LAST message was an assistant with tool_calls, but the NEW message is NOT a tool result,
		# we MUST strip the tool_calls from the last message. Otherwise, the protocol is violated.
		if last.role == "assistant" and last.has("tool_calls") and msg.role != "tool":
			last.erase("tool_calls")
			# If the assistant message is now empty (no content and no tools), we should ideally 
			# merge it or remove it, but stripping the tools is the bare minimum to fix the template.
			if last.get("content", "").is_empty():
				last.content = "..." # Fallback content
		
		sanitized.append(msg)
		
	return sanitized
