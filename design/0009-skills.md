# AI Skill System Design (Node-Based)

## REQ-SKILL-0001: Node-Based Skill Architecture

The AI Skill System allows extending the AI agent with specialized domain knowledge and tools by adding `AISkill` nodes to the scene tree. This architecture leverages Godot's built-in node lifecycle and tree structure for discovery, state management, and contextual awareness.

### Core Components

1.  **AISkill** (Node): A specialized node type that contains instructions, tool definitions, and the actual implementation logic as GDScript methods.
2.  **Scene-Tree Discovery**: AI nodes (like `AIChat`) scan their descendants to find active `AISkill` nodes.
3.  **Dynamic Routing**: The `AIRequestHandler` routes tool calls directly to the discovered `AISkill` node instances using `Object.call()`.

---

## REQ-SKILL-0002: AISkill Node Structure

An `AISkill` node is defined by the following properties and behaviors:

### 1. Properties
- `description` (String): A one-line summary of the skill's purpose (e.g., "Finds and filters nodes in the scene tree").
- `definition` (Multiline String): The full expert instructions for the AI, describing how to use the skill and its tools.
- `tools` (Array[Dictionary]): An array of OpenAI-compatible JSON schemas for each function the node provides.
- `is_active` (bool): Toggles whether the skill is visible to the AI discovery process.

### 2. Implementation
The logic for the skill's tools is implemented as standard GDScript methods within a script attached to the `AISkill` node.

```gdscript
extends AISkill

func find_nodes(arguments: Dictionary) -> String:
    var pattern = arguments.get("pattern", "*")
    var results = []
    # Implementation logic using Godot APIs...
    return JSON.stringify(results)
```

---

## REQ-SKILL-0003: Skill Discovery via Scene Tree

Skills are no longer loaded from static directories. Instead, they are discovered dynamically within the active scene.

### 1. Discovery Process
When `AIChat` prepares a request:
1.  It iterates through all its descendants.
2.  It identifies any node that is an instance of `AISkill` where `is_active == true`.
3.  It collects the node's `name` and `description`.

### 2. Precedence and Scope
- Skills are scoped to the AI node that discovers them.
- If multiple `AISkill` nodes have the same name, the first one found (depth-first) takes precedence, or they are treated as distinct if they have different paths.
- This allows for "contextual skills": a character node could have its own `AISkill` child that only becomes available when the user is chatting with that specific character's `AIChat` component.

---

## REQ-SKILL-0005: Lazy Loading & Activation

To optimize context usage, the system uses a two-stage activation process.

### 1. Discovery Phase (Initial Prompt)
The `PromptBuilder` lists available skills in the system prompt with just their names and descriptions:

```
Available Skills:
- NodeFinder: Finds and filters nodes in the scene tree.
- PhysicsTweak: Tools for adjusting physics materials.
Use 'activate_skill(name)' to access a skill's full instructions and tools.
```

### 2. Activation Phase (Dynamic Tool Injection)
The built-in `activate_skill(name: String)` tool performs the following:

1.  **Instruction Injection**: Returns the node's `definition` property. This adds the expert guidance to the conversation history.
2.  **Tool Registration**: The `AIRequestHandler` reads the `tools` array from the node and registers those functions in its session state for the **next turn**.
3.  **Routing Setup**: The handler maps the registered tool names to the specific `AISkill` node instance.

---

## REQ-SKILL-0006: The Skill-Creator (Node Generator)

The `skill-creator` is now a tool that helps the user (or the AI itself) configure `AISkill` nodes.

1.  **AI Usage**: The AI can generate the GDScript and JSON schemas for a new `AISkill` node and use the `execute_script` or `modify_project_resource` tools to add it to the scene.
2.  **Template**: A base `ai_skill.gd` script provides the foundation for all skill nodes, ensuring they have the necessary properties and are recognized by the discovery system.

---

## REQ-SKILL-0007: Lifecycle and Synchronization Limitations

The Skill System is designed for performance and context efficiency, which introduces specific behaviors regarding updates:

### 1. Metadata Snapshotting
When `activate_skill` is called, the skill's `definition` (instructions) and `tools` (JSON schemas) are snapshotted and injected into the AI's current session context.
- **Static Instructions**: Once instructions are injected into the conversation history, they are immutable for the remainder of that session. Updating the `definition` on the node will NOT update the instructions the AI has already read.
- **Static Schemas**: The `AIRequestHandler` caches the tool schemas at activation. Adding, removing, or renaming tools on the node after activation will not be reflected in the AI's available functions until the session is reset.

### 2. Live Logic Execution
Unlike metadata, the **implementation logic** (the GDScript methods) is resolved dynamically via `Object.call()`.
- If a user modifies the *code* inside an existing tool method, the AI will execute the updated logic immediately on the next call.
- However, if the method signature (arguments) changes, the AI will likely fail because it is still using the old schema it received at activation.

### 3. Re-activation
Currently, `activate_skill` returns early if a skill is already marked as active. To force an update of instructions or schemas, the session history must be cleared, or the `activated_skill_ids` list in the handler must be reset.

### `AISkill` Base Class
```gdscript
class_name AISkill
extends Node

@export_group("AI Skill Metadata")
@export var description: String = ""
@export_multiline var definition: String = ""
@export var is_active: bool = true

## Array of OpenAI function schemas.
@export var tools: Array[Dictionary] = []
```

### Dynamic Routing in `AIRequestHandler`
```gdscript
var _dynamic_tool_targets: Dictionary = {} # tool_name -> AISkill node

func activate_skill(skill_name: String) -> String:
    var skill_node = _find_skill_node(skill_name)
    for tool_schema in skill_node.tools:
        var tool_name = tool_schema.function.name
        _dynamic_tool_targets[tool_name] = skill_node
    return skill_node.definition

func _execute_tool(tool_call: Dictionary) -> String:
    var name = tool_call.function.name
    if _dynamic_tool_targets.has(name):
        var target = _dynamic_tool_targets[name]
        var args = JSON.parse_string(tool_call.function.arguments)
        return await target.call(name, args)
    # ... fallback to built-in tools ...
```
