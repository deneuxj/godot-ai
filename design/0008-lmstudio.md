# LM Studio Integration Design

## REQ-LMSTUDIO-0001 & REQ-LMSTUDIO-0002: Native Client

### `LMStudioClient` (extends `AIClient`)

This client handles standard OpenAI calls but adds methods for native LM Studio control.

```gdscript
class_name LMStudioClient extends OpenAIClient

signal load_progress(percent: float)

func load_model(model_id: String) -> Error:
    # POST /api/v1/models/load { "identifier": model_id }
    # Use chunked response to track progress if supported
    pass

func unload_model(model_id: String) -> Error:
    # POST /api/v1/models/unload { "identifier": model_id }
    pass

func get_local_models() -> Array:
    # GET /api/v1/models
    pass
```

### Auto-Detection Logic

When `AIRequestHandler` initializes, it pings the base URL:
1. Try `GET /api/v1/models`.
2. If it returns 200 and a valid LM Studio model list, upgrade the client to `LMStudioClient`.
3. Otherwise, fall back to `OpenAIClient`.

---

## REQ-LMSTUDIO-0003: Predictive Loading in Router

Modified `AIChat.send_message` logic:
1. Run router (fast model).
2. Once the target model (Analyst/Technician) is chosen:
3. If using `LMStudioClient`:
    - Call `await load_model(target_model)`.
    - Handle timeout/errors.
4. Proceed with standard chat completion.

---

## REQ-LMSTUDIO-0004 & REQ-LMSTUDIO-0005: UI and Manual Control

### Editor UI Integration
- Add "Unload" icon next to the model name in `AIChatPanel`.
- Status bar updates with "Loading [Model]: 45%" during `load_model` execution.

### Memory Policy
- Default: Keep models loaded.
- Manual: User clicks "Unload" in the panel.

---

## Requirements Coverage

| Requirement | Covered By |
|---|---|
| REQ-LMSTUDIO-0001 | Auto-detection logic in `AIRequestHandler` |
| REQ-LMSTUDIO-0002 | `LMStudioClient.gd` implementation |
| REQ-LMSTUDIO-0003 | Routing logic update in `AIChat.gd` |
| REQ-LMSTUDIO-0004 | Progress signal connection in `AIChatPanel.gd` |
| REQ-LMSTUDIO-0005 | Manual unload method and UI button |
