# AI Integration Design

## REQ-AIINTG-0001: The plugin shall support both local and remote LLM backends

### Interface (`ai_client/ai_client.gd`)

```gdscript
class_name AIClient
extends Node

signal progress(chunks: Array[String])

# ... request methods ...

func cancel() -> void:
	push_error("Override in subclass")
```

### Implementation (`ai_client/openai_client.gd`)

```gdscript
class_name OpenAIClient
extends AIClient

var _http_request: HTTPRequest

func cancel() -> void:
	if is_instance_valid(_http_request):
		_http_request.cancel_request()

func chat_stream(messages: Array[Dictionary]) -> String:
	# ... request setup ...
	var result = await _http_request.request_completed
	if result[0] != OK: # Includes RESULT_REQUEST_CANCELLED
		return ""
	# ... parse response ...
```

---

## REQ-AIINTG-0004: Project settings for AI configuration

### Settings (`settings/ai_settings.gd`)

| Setting | Default | Description |
|---|---|---|
| `ai/openai/base_url` | `http://localhost:1234/v1` | API endpoint URL |
| `ai/openai/api_key` | `""` | Authentication key |
| `ai/openai/model` | `local-model` | Model name |
| `ai/openai/max_tokens` | `4096` | Max response tokens |
| `ai/openai/max_retries` | `5` | Max correction attempts (REQ-AIINTG-0006) |

---

## Requirements Coverage

| Requirement | Covered By |
|---|---|
| REQ-AIINTG-0001 | `AIClient` abstract class + `OpenAIClient` implementation |
| REQ-AIINTG-0004 | `AISettings` manages configuration including `max_retries` |
| REQ-AIINTG-0006 | Configurable `max_retries` in `AISettings` |
| REQ-NODE3D-0010 | `AIClient.cancel()` method implementation |
