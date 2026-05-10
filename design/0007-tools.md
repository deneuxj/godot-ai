# AI Tool System Design

## REQ-TOOL-0001: Extensible Tool/Function Calling System

The system will leverage the OpenAI "tools" (function calling) protocol. This allows the AI to request the execution of specific Godot-side functions and receive the results as part of the conversation history.

### Architecture

1. **AITool** (Base Class/Registry): Defines the interface for tools.
2. **AIClient**: Updated to handle `tool_calls` in the AI response and send back `tool` results.
3. **Tool Implementations**:
    - `GodotDocsTool`: Interfaces with `EditorInterface` or `DocData`.
    - `ProjectResourcesTool`: Interfaces with `EditorFileSystem` and `DirAccess`.

---

## REQ-TOOL-0002: Godot Documentation Tool (`explore_godot_docs`)

### Specification
- **Method**: `list_classes(filter: String = "") -> Array`
- **Method**: `get_class_doc(class_name: String) -> Dictionary`

### Implementation Detail
Uses `ClassDB` to list available classes and properties. For detailed documentation, it may need to access the XML-based doc data if available in the editor context or use `help_property_get` and similar metadata methods.

---

## REQ-TOOL-0003: Project Resources Tool (`explore_project_resources`)

### Specification
- **Method**: `list_files(path: String = "res://", filter: String = "") -> Array`
- **Method**: `get_resource_info(path: String, start_line: int = 1, end_line: int = -1) -> Dictionary`
    - Returns metadata and content for text-based resources.
    - Supports optional line range selection (`start_line` to `end_line`) for reading specific blocks of code/text.

### Implementation Detail
Uses `DirAccess` for file listing. `get_resource_info` provides metadata about scenes (root node type) or scripts (class_name, exported properties).

---

## REQ-TOOL-0006: Modify Project Resource Tool (`modify_project_resource`)

### Specification
- **Method**: `modify_resource(path: String, target_line: int, old_content: String, new_content: String) -> Dictionary`
- **Parameters**:
    - `path`: The `res://` path to the file.
    - `target_line`: The 1-based line where the change is expected to start.
    - `old_content`: The exact text block expected to be replaced. (Empty for new files).
    - `new_content`: The new text block to insert.

### Implementation Detail
1. **New File**: If the file doesn't exist and `old_content` is empty, create the file and parent directories.
2. **Flexible Matching**: 
    - Search for `old_content` in the file, starting at `target_line` and checking a small window (e.g., +/- 5 lines).
    - If found, replace the block.
    - If not found exactly at `target_line` or within the window, return an error with the actual lines found at `target_line` to help the AI recalibrate.
3. **Safety**: Only allows modifying text-based files.

---

## REQ-TOOL-0007: Validate Project Resource Tool (`validate_project_resource`)

### Specification
- **Method**: `validate_resource(path: String) -> Dictionary`
- **Parameters**:
    - `path`: The `res://` path to the resource to validate.

### Implementation Detail
1. **Script Validation**: For `.gd` files, use `GDScript.new()` and `reload()` to check for parse errors.
2. **General Resource Validation**: For other extensions, use `ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)` to attempt loading.
3. **Error Capture**: Wrap the validation logic with the `Logger` (similar to `ScriptExecutor`) to capture internal engine errors and warnings.
4. **Detailed Feedback**: Return a structured response indicating success/failure and the captured errors.

---

## REQ-TOOL-0004: Tool Control Properties

`AIAgentAssisted3D` and `AIChat` will have a new property group:

```gdscript
@export_group("Tools")
@export var enable_godot_docs: bool = true
@export var enable_project_resources: bool = true
```

When building the request, the `PromptBuilder` or the node will collect the definitions of enabled tools and pass them to the `AIClient`.

---

## Tool Execution Flow

1. AI receives user prompt.
2. AI decides to use a tool and returns a `tool_calls` message.
3. `AIRequestHandler` intercepts the `tool_calls`.
4. The corresponding Godot function is executed.
5. The result is appended to the conversation as a `tool` role message.
6. A new completion request is sent to the AI with the tool results.
7. This repeats until the AI provides a final answer (or hits a loop limit).

---

## Requirements Coverage

| Requirement | Covered By |
|---|---|
| REQ-TOOL-0001 | Design of the Tool System and `AIRequestHandler` loop |
| REQ-TOOL-0002 | `GodotDocsTool` implementation details |
| REQ-TOOL-0003 | `ProjectResourcesTool` implementation details |
| REQ-TOOL-0006 | `ModifyProjectResourceTool` implementation details |
| REQ-TOOL-0007 | `ValidateProjectResourceTool` implementation details |
| REQ-TOOL-0008 | `BuildDynamicSceneTool` implementation details |
| REQ-TOOL-0004 | `@export` properties in node classes |
| REQ-TOOL-0005 | `AIRequestHandler` logging of tool calls |
_docs: bool = true
@export var enable_project_resources: bool = true
```

When building the request, the `PromptBuilder` or the node will collect the definitions of enabled tools and pass them to the `AIClient`.

---

## Tool Execution Flow

1. AI receives user prompt.
2. AI decides to use a tool and returns a `tool_calls` message.
3. `AIRequestHandler` intercepts the `tool_calls`.
4. The corresponding Godot function is executed.
5. The result is appended to the conversation as a `tool` role message.
6. A new completion request is sent to the AI with the tool results.
7. This repeats until the AI provides a final answer (or hits a loop limit).

---

## Requirements Coverage

| Requirement | Covered By |
|---|---|
| REQ-TOOL-0001 | Design of the Tool System and `AIRequestHandler` loop |
| REQ-TOOL-0002 | `GodotDocsTool` implementation details |
| REQ-TOOL-0003 | `ProjectResourcesTool` implementation details |
| REQ-TOOL-0006 | `ModifyProjectResourceTool` implementation details |
| REQ-TOOL-0007 | `ValidateProjectResourceTool` implementation details |
| REQ-TOOL-0004 | `@export` properties in node classes |
| REQ-TOOL-0005 | `AIRequestHandler` logging of tool calls |
