# AI Assistant Testing Documentation

This document describes the testing infrastructure for the Godot AI Assistant plugin, including how to run tests and how to use the mocking system for offline development.

## Testing Philosophy

We use a combination of:
1. **Tool-Specific Unit Tests**: Testing the raw logic of individual tools.
2. **Mock AI Integration Tests**: Testing the full pipeline (Chat -> Request Handler -> Tool -> Response) using a fake LLM.
3. **Headless Execution**: All tests are designed to run in Godot's `--headless` mode for CI/CD compatibility.

---

## The Mocking System

To test the AI Assistant without an active internet connection or a running LLM (like LM Studio or OpenAI), we use the `MockAIClient`.

### `MockAIClient` (`res://addons/ai_assistant/ai_client/mock_ai_client.gd`)
This class simulates an AI backend. You can queue responses for it to return when `AIChat` sends a message.

**Usage Example:**
```gdscript
var chat = AIChat.new()
var mock = MockAIClient.new()
chat.mock_client = mock

# Queue a plain text response
mock.response_queue.append("Hello! I am a mock AI.")

# Queue a tool call
mock.response_queue.append({
    "tool_calls": [{
        "id": "1",
        "type": "function",
        "function": {
            "name": "build_dynamic_scene",
            "arguments": "{\"script_content\": \"...\", \"add_to_tree\": true}"
        }
    }]
})

chat.send_message("Please help me.")
```

---

## Available Test Suites

### 1. Build Dynamic Scene Tool Test
**Files:** `project/testing/test_build_dynamic_scene_tool.tscn` / `.gd`
**Purpose:** Verifies the `BuildDynamicSceneTool` can compile GDScript, instantiate nodes, handle memory correctly (no leaks), and report errors for invalid scripts.

### 2. Comprehensive Tool Mock Test
**Files:** `project/testing/test_all_tools_mock.tscn` / `.gd`
**Purpose:** Tests the integration of ALL available tools. It simulates an AI deciding to use each tool and verifies that the tools execute and return valid results.
**Tools covered:**
- `explore_godot_docs`
- `explore_project_resources`
- `modify_project_resource` (Create and Patch)
- `validate_project_resource`
- `build_dynamic_scene`

---

## How to Run Tests

You can run these tests from the command line using the Godot executable.

### Running Headlessly (Recommended)
Navigate to the root of the repository and run:

```bash
# Run the specific tool test
./godot.sh --headless --path project/ testing/test_build_dynamic_scene_tool.tscn

# Run the comprehensive mock test
./godot.sh --headless --path project/ testing/test_all_tools_mock.tscn
```

### Running in Editor
1. Open the project in the Godot Editor.
2. Open the desired `.tscn` file (e.g., `test_all_tools_mock.tscn`).
3. Press **F6** (Run Current Scene).
4. Check the **Output** tab for results.

---

## Troubleshooting Tests

- **Leak Warnings**: If you see "ObjectDB instances leaked at exit", it usually means a node created during the test wasn't freed. The `BuildDynamicSceneTool` includes logic to prevent this, but custom test scripts should always `free()` any nodes they instantiate.
- **XML Errors**: During `explore_godot_docs` tests, you may see XML parsing errors. These are expected if `ai/tools/godot_source_path` is not configured, as the tool attempts to find documentation in the engine source.
- **No Loader Found**: During `validate_project_resource` tests, errors like "No loader found for .txt" are expected if you attempt to validate a non-engine resource (like a plain text file) as if it were a Scene or Script.
