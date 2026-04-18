# Editor UX Design

## REQ-EDITOR-0001: Real-time progress feedback in the Godot editor during AI processing

### Progress Signal Flow

```
OpenAIClient.chat_stream()
    │
    ├─ emits "progress" signal per token/chunk
    │
    ▼
AgentAssisted3D
    │
    ├─ updates status_message with token count
    ├─ emits "progress" signal
    │
    ▼
AgentAssisted3DPanel (editor dock)
    │
    ├─ updates progress bar
    └─ updates token count display
```

### Implementation

In `OpenAIClient`:

```gdscript
signal progress(chunks: Array[String])

func chat_stream(messages: Array[Dictionary]) -> String:
    # ... HTTP request setup ...
    
    var full_response = ""
    
    # Parse SSE stream
    for line in stream_lines:
        if line.begins_with("data: "):
            var data = line.substr(6)
            if data == "[DONE]":
                break
            
            var parsed = JSON.parse_string(data)
            var content = parsed["choices"][0]["delta"]["content"]
            full_response += content
            chunks.append(content)
    
    emit_signal("progress", chunks)
    return full_response
```

In `AgentAssisted3D`:

```gdscript
signal progress(chunks: Array[String])

func _on_ai_progress(chunks: Array[String]):
    var token_count = _estimate_tokens(chunks.join(""))
    status_message = "Generating... (%d tokens)" % token_count
    emit_signal("progress", chunks)
```

### UI Feedback

The editor dock shows:
- Progress bar filled proportionally to estimated tokens (based on typical response length)
- Token count text: "Generating... (1,234 tokens)"
- Status text updates in real-time

---

## REQ-EDITOR-0002: Custom editor dock for the AgentAssisted3D node

### Editor Dock Scene (`agent_assisted_3d_panel.tscn`)

```
┌─────────────────────────────────────┐
│  Agent Assisted 3D                  │
├─────────────────────────────────────┤
│  Prompt:                          [x]│
│  ┌───────────────────────────────┐  │
│  │                               │  │
│  │          (text area)          │  │
│  │                               │  │
│  └───────────────────────────────┘  │
│                                     │
│  Attachments:                       │
│  ┌───────────────────────────────┐  │
│  │ (drag textures here)          │  │
│  │ [texture1.png  ✕]            │  │
│  └───────────────────────────────┘  │
│                                     │
│  [⟳ Generate]  [Clear]              │
│                                     │
│  Status:  Generating... ████████░░  │
│                                     │
│  Node Tree:                         │
│  ┌───────────────────────────────┐  │
│  │ └─ Node3D                    │  │
│  │    ├─ MeshInstance3D         │  │
│  │    └─ DirectionalLight3D     │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### Scene Structure

```
AgentAssisted3DPan
├── VBoxContainer
│   ├── Label (title "Agent Assisted 3D")
│   ├── Label ("Prompt:")
│   ├── TextEdit (prompt_text_edit)
│   │   ├── clear_button
│   ├── Label ("Attachments:")
│   ├── VBoxContainer (attachments_container)
│   │   ├── Label ("Drag textures here")
│   ├── HBoxContainer (button_row)
│   │   ├── Button (generate_button)
│   ├── HBoxContainer (status_row)
│   │   ├── Label (status_label)
│   │   ├── ProgressBar (progress_bar)
│   ├── Label ("Node Tree:")
│   └── Tree (node_tree_view)
```

### Dock Controller (`agent_assisted_3d_panel.gd`)

```gdscript
extends Control

var _current_node: AgentAssisted3D = null

func _ready():
    # Connect to currently selected node if it's an AgentAssisted3D
    _update_for_selected_node()

func _on_selection_changed():
    var selected = get_editor_interface().get_selection().get_selected_nodes()
    if selected.size() > 0 and selected[0] is AgentAssisted3D:
        _update_for_selected_node()

func _update_for_selected_node():
    if _current_node:
        _current_node.disconnect("progress", self, "_on_node_progress")
    
    var selected = get_editor_interface().get_selection().get_selected_nodes()
    _current_node = selected[0] if selected.size() > 0 and selected[0] is AgentAssisted3D else null
    
    if _current_node:
        prompt_text_edit.text = _current_node.prompt
        _current_node.connect("progress", self, "_on_node_progress")
        _refresh_attachments()
        _refresh_node_tree()
    else:
        prompt_text_edit.text = ""
        status_label.text = "No AgentAssisted3D selected"

func _on_generate_pressed():
    if _current_node:
        _current_node.generate()

func _on_node_progress(chunks: Array[String]):
    var token_count = _estimate_tokens(chunks.join(""))
    status_label.text = "Generating... (%d tokens)" % token_count
    progress_bar.value = min(100.0, token_count / 40.0)  # Rough estimate

func _on_prompt_text_edit_text_changed():
    if _current_node:
        _current_node.prompt = prompt_text_edit.text

func _refresh_attachments():
    # Clear and rebuild attachment list from _current_node.texture_attachments
    pass

func _refresh_node_tree():
    # Build tree view from _current_node.get_generated_nodes()
    pass
```

### Drag & Drop Textures

```gdscript
func _can_drop_data(position, data):
    if data is Dictionary and "files" in data:
        for file in data["files"]:
            if file.get_extension().to_lower() in ["png", "jpg", "jpeg", "bmp", "webp"]:
                return true
    return false

func _drop_data(position, data):
    var textures = []
    for file in data["files"]:
        var texture = load(file)
        if texture is Texture2D:
            textures.append(texture)
    
    if _current_node:
        _current_node.texture_attachments = textures
        _refresh_attachments()
```

---

## REQ-EDITOR-0003: Generation status exposed as a node property

### Status Enum

```gdscript
enum GenerationStatus {
    IDLE,       # Ready to generate
    GENERATING, # AI request in progress
    SUCCESS,    # Generation completed successfully
    ERROR       # Generation failed
}
```

### Property Binding

The `generation_status` property is exposed in the Godot editor's inspector when the node is selected. The dock also displays the status in the `status_label`.

### Status Transitions

```
IDLE ──generate()──→ GENERATING ──success──→ SUCCESS
                    ──error──────→ ERROR  ──retry──→ GENERATING
```

### Error Display

When `generation_status == ERROR`, the `status_message` contains the error details:

```gdscript
func _on_generation_failed(message: String):
    generation_status = GenerationStatus.ERROR
    status_message = message
    status_label.text = "Error: " + message
    status_label.add_theme_color_override("font_color", Color.RED)
```

---

## Requirements Coverage

| Requirement | Covered By |
|---|---|
| REQ-EDITOR-0001 | Progress signal chain: `OpenAIClient` → `AgentAssisted3D` → dock, real-time token count and progress bar updates |
| REQ-EDITOR-0002 | `agent_assisted_3d_panel.tscn` scene with prompt text area, texture drag-and-drop, generate button, status indicator, node tree preview; `agent_assisted_3d_panel.gd` controller |
| REQ-EDITOR-0003 | `generation_status` enum property exposed in inspector and dock; status transitions (IDLE → GENERATING → SUCCESS/ERROR) |
