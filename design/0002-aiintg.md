# AI Integration Design

## REQ-AIINTG-0001: The plugin shall support both local and remote LLM backends

The `AIClient` and `OpenAIClient` classes provide the bridge to the LLM. 

### Implementation (`ai_client/openai_client.gd`)
Uses standard OpenAI Chat Completions API with streaming support.

---

## REQ-AIINTG-0003: GDScript Generation

### Prompt Builder (`generator/prompt_builder.gd`)

The `PromptBuilder` constructs the system prompt based on the selected `GenerationMode` and execution environment.

#### Context Injection (REQ-AIINTG-0008)
The `PromptBuilder` automatically includes runtime information:
- **Environment:** `Engine.is_editor_hint()` determines if running in "Godot Editor" or "Game".
- **Node Context:** The name and path of the node initiating the request.
- **Reference Resolution:** Explicitly instructs the AI that "this node" refers to the owner of the `AIChat` or `AIAgentAssisted3D` instance.

#### Scripted Scene Mode System Prompt
```text
You are a Godot 4 scene builder.
Output a GDScript that constructs a 3D scene hierarchy.
Your script MUST implement a `build() -> Node3D` method that returns the root of the constructed hierarchy.
Use standard Node3D, MeshInstance3D, etc.
IMPORTANT: You must set the 'owner' property of every child node to the root node you return for serialization to work.
Example:
func build() -> Node3D:
    var root = Node3D.new()
    var mesh = MeshInstance3D.new()
    root.add_child(mesh)
    mesh.owner = root
    return root
```

#### Node Script Mode System Prompt
```text
You are a Godot 4 GDScript generator.
Output valid GDScript code for a single script.
You MAY use markdown code blocks (```gdscript ... ```).
The script should extend Node3D and implement logic based on the user request.
```

#### Analyst Mode System Prompt (REQ-AIINTG-0009)
```text
You are a Godot 4 Architectural Analyst.
Your goal is to understand complex user requests and design a robust implementation plan.
1. Analyze the request and the current project context.
2. Provide a step-by-step implementation plan.
3. DO NOT implement the code or call tools that modify the project.
4. End your response by asking the user if they want to proceed with this plan.
The goal is to allow a Technician model to handle the actual implementation once the plan is approved.
```

### Prompt Construction
```gdscript
static func build(prompt: String, textures: Array[Texture2D], mode: GenerationMode) -> Array[Dictionary]:
    var system_prompt = _get_system_prompt_for_mode(mode)
    # ... build messages array ...
```

---

## REQ-AIINTG-0005: Error Correction Loop

The loop is triggered by **Validation Errors** (parse/load errors) captured via high-fidelity engine feedback.

### Validation (`ScriptExecutor.validate_output`)

Before validation, the `ScriptExecutor` extracts the raw code from markdown fences if present using `ScriptExecutor.extract_code()`.

1. **Scripted Scene Mode**:
    - Extracts GDScript code from fences.
    - Performs **GDScript Validation** using `GDScript.reload()` to catch syntax errors.
    - **Executes the script** and calls `build()`.
    - Captures any runtime errors (e.g., property not found) via the `CustomLogger`.
    - If successful, verifies the returned object is a `Node3D`.
2. **Node Script Mode**: 
    - Extracts code from fences.
    - Performs **GDScript Validation** using `GDScript.reload()` to catch syntax and parse errors.

### Conversation Structure
When an error occurs, the conversation history is updated as follows:
1. **Assistant**: The previous (invalid) output from the AI.
2. **User**: The validation error message and instruction to provide a corrected version.

---

## Requirements Coverage

| Requirement | Covered By |
|---|---|
| REQ-AIINTG-0001 | `AIClient` abstract class + `OpenAIClient` implementation |
| REQ-AIINTG-0003 | `PromptBuilder` logic for Mode-specific output |
| REQ-AIINTG-0005 | `AIAgentAssisted3D` validation loop and `PromptBuilder.build_error_correction()` |
| REQ-AIINTG-0004 | `AISettings` manages configuration under `ai/connection/` and `ai/generation/` |
| REQ-AIINTG-0006 | Configurable `max_retries` in `AISettings` |
| REQ-AIINTG-0008 | `PromptBuilder` context injection logic |
| REQ-AIINTG-0009 | `PromptBuilder` Analyst-specific system prompt |
| REQ-NODE3D-0010 | `AIClient.cancel()` method implementation |
