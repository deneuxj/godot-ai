# AI Integration Design

## REQ-AIINTG-0001: The plugin shall support both local and remote LLM backends

### Architecture

The `AIClient` abstract class (extends `Node`) defines the interface. `OpenAIClient` implements it for OpenAI-compatible APIs (LM Studio, Ollama, OpenAI, etc.). Both classes extend `Node` to participate in the scene tree — `AIClient` for the `progress` signal lifecycle, `OpenAIClient` to host an `HTTPRequest` child node.

```
┌──────────────┐
│   AIClient   │ (abstract, extends Node)
│   (base)     │
└──────┬───────┘
       │ extends
       ▼
┌──────────────┐
│ OpenAIClient │ (extends Node, hosts HTTPRequest)
└──────────────┘
```

### Interface (`ai_client/ai_client.gd`)

```gdscript
class_name AIClient
extends Node

signal progress(chunks: Array[String])

var endpoint: String = "http://localhost:1234/v1"
var api_key: String = ""
var model: String = "local-model"
var max_tokens: int = 4096

# Non-streaming: returns full response
func chat(messages: Array[Dictionary]) -> String:
	push_error("Override in subclass")
	return ""

# Streaming: yields chunks via [signal progress], returns full content
func chat_stream(messages: Array[Dictionary]) -> String:
	push_error("Override in subclass")
	return ""

# Set request parameters (returns self for method chaining)
func set_endpoint(url: String) -> AIClient:
	endpoint = url
	return self

func set_api_key(key: String) -> AIClient:
	api_key = key
	return self

func set_model(model_name: String) -> AIClient:
	model = model_name
	return self

func set_max_tokens(tokens: int) -> AIClient:
	max_tokens = tokens
	return self

# Factory: creates OpenAIClient configured from project settings
static func create_openai_client() -> OpenAIClient:
	var client := OpenAIClient.new()
	client.set_endpoint(AISettings.get_string("base_url"))
	client.set_api_key(AISettings.get_string("api_key"))
	client.set_model(AISettings.get_string("model"))
	client.set_max_tokens(AISettings.get_int("max_tokens"))
	return client
```

### Implementation (`ai_client/openai_client.gd`)

Uses Godot's `HTTPRequest` node (created in `_ready()`) to call the OpenAI-compatible API.

```gdscript
class_name OpenAIClient
extends AIClient

var _http_request: HTTPRequest

func _ready() -> void:
	_http_request = HTTPRequest.new()
	add_child(_http_request)

func chat(messages: Array[Dictionary]) -> String:
	var body = {
		"model": model,
		"messages": messages,
		"max_tokens": max_tokens
	}

	var headers = ["Content-Type: application/json"]
	if api_key != "":
		headers.append("Authorization: Bearer " + api_key)

	var error = _http_request.request(
		endpoint + "/v1/chat/completions",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)

	# Wait for request_completed signal
	var response = await _http_request.request_completed
	var result = JSON.parse_string(response[3])
	return result["choices"][0]["message"]["content"]

func chat_stream(messages: Array[Dictionary]) -> String:
	# Similar to chat(), but sets "stream": true in the body
	# Parses SSE stream chunks from response[2] (raw string)
	# Emits progress signal with each chunk
	# Returns the full concatenated content string
	pass
```

### Configuration

Project settings determine which backend is used:

| Setting | Default | Example (LM Studio) | Example (OpenAI) |
|---|---|---|---|
| `ai/openai/base_url` | `http://localhost:1234/v1` | `http://localhost:1234/v1` | `https://api.openai.com/v1` |
| `ai/openai/api_key` | `""` | `""` (no auth) | `sk-...` |
| `ai/openai/model` | `local-model` | `local-model` | `gpt-4` |

Any OpenAI-compatible server works by setting `base_url` appropriately.

---

## REQ-AIINTG-0002: The plugin shall use an OpenAI-compatible API protocol

The `OpenAIClient` implements the standard OpenAI chat completions API:

- **Endpoint:** `{base_url}/v1/chat/completions`
- **Method:** `POST`
- **Request body:**
  ```json
  {
    "model": "<model>",
    "messages": [
      {"role": "system", "content": "<system prompt>"},
      {"role": "user", "content": "<user message with optional images>"}
    ],
    "max_tokens": <max_tokens>
  }
  ```
- **Response parsing:** Extracts `choices[0].message.content`

Streaming uses Server-Sent Events (SSE) format:

```
data: {"choices":[{"delta":{"content":"Hello"}}]}
data: {"choices":[{"delta":{"content":" world"}}]}
data: [DONE]
```

Each chunk is parsed and emitted as a progress event to the editor dock.

---

## REQ-AIINTG-0003: The AI shall output GDScript code that programmatically creates the node tree

### Prompt Builder (`generator/prompt_builder.gd`)

Constructs the AI request with instructions to output GDScript:

```gdscript
class PromptBuilder:
    
    static var DEFAULT_SYSTEM_PROMPT := """
You are a Godot 4 scene generation assistant.
Given a user prompt and optional visual references,
generate GDScript code that creates a node hierarchy.

Rules:
- Output ONLY valid GDScript code, no markdown fences
- Use Node3D, MeshInstance3D, DirectionalLight3D, etc.
- Set reasonable default properties (position, scale, material)
- Use clear variable names and add helpful comments
- The root node should be a Node3D with the script attached
- Use standard Godot 4 API (no deprecated methods)
- Keep the scene performant and well-organized
"""
    
    static func build(user_prompt: String, textures: Array[Texture2D]) -> Array[Dictionary]:
        var system_prompt = _get_system_prompt()  # From project setting or default
        
        var user_content = user_prompt
        if textures.size() > 0:
            user_content += "\n\nVisual references attached below."
        
        var messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_content}
        ]
        
        # Add textures as base64 if multimodal model
        if textures.size() > 0:
            messages[1]["content"] = _build_multimodal_content(user_content, textures)
        
        return messages
    
    static func build_error_correction(messages: Array[Dictionary], error_result: Dictionary) -> Array[Dictionary]:
        """Append error details to the conversation to ask the AI to fix the script."""
        var fix_instruction := """
The previous script had the following error:

Error: %s
File: %s
Line: %s

Please provide a corrected version of the script that resolves this error.
Output ONLY valid GDScript code, no markdown fences.
""" % [error_result.error, error_result.file, error_result.line]
        
        messages.append({
            "role": "user",
            "content": fix_instruction
        })
        
        return messages
    
    static func _get_system_prompt() -> String:
        return ProjectSettings.get_setting(
            "ai/openai/system_prompt", DEFAULT_SYSTEM_PROMPT
        )
```

### System Prompt Override

The project setting `ai/openai/system_prompt` is checked first. If not set, the built-in default is used. This allows advanced users to customize the AI's behavior (REQ-AINT-0004).

---

## REQ-AIINTG-0004: Project settings for AI configuration

### Settings (`settings/ai_settings.gd`)

```gdscript
class AISettings:
    
    static var DEFAULTS := {
        "base_url": "http://localhost:1234/v1",
        "api_key": "",
        "model": "local-model",
        "max_tokens": 4096,
        "timeout_ms": 60000
    }
    
    static func ensure_settings_exist():
        for key in DEFAULTS:
            var setting = "ai/openai/" + key
            if not ProjectSettings.has_setting(setting):
                ProjectSettings.set_setting(setting, DEFAULTS[key])
                ProjectSettings.set_initial_value(setting, DEFAULTS[key])
        
        # Optional system prompt (no default)
        if not ProjectSettings.has_setting("ai/openai/system_prompt"):
            ProjectSettings.set_setting("ai/openai/system_prompt", "")
            ProjectSettings.set_initial_value("ai/openai/system_prompt", "")
        
        ProjectSettings.save()
    
    static func get_string(key: String) -> String:
        return ProjectSettings.get_setting("ai/openai/" + key, DEFAULTS[key])
    
    static func get_int(key: String) -> int:
        return ProjectSettings.get_setting("ai/openai/" + key, DEFAULTS[key])
```

### Auto-configuration on Plugin Enable

In `ai_assistant.gd`:

```gdscript
func _enter_tree():
    AISettings.ensure_settings_exist()
```

---

## Requirements Coverage

| Requirement | Covered By |
|---|---|
| REQ-AIINTG-0001 | `AIClient` abstract class + `OpenAIClient` implementation, configurable `base_url` and `api_key` settings |
| REQ-AIINTG-0002 | `OpenAIClient` implements OpenAI chat completions API (POST `/v1/chat/completions`), SSE streaming support |
| REQ-AIINTG-0003 | `PromptBuilder` constructs system prompt instructing GDScript output, user message with prompt + textures |
| REQ-AIINTG-0004 | `AISettings` class manages all project settings, auto-creates them on plugin enable, supports `system_prompt` override |
| REQ-AIINTG-0005 | `PromptBuilder.build_error_correction()` appends error details as user messages, `generate()` in `design/0001-node3d.md` loops until success or `MAX_RETRIES` |
