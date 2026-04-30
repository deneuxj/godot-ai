# Editor UX Design

## REQ-EDITOR-0002: Custom editor dock for the AgentAssisted3D node

### Editor Dock Scene (`agent_assisted_3d_panel.tscn`)

```
┌─────────────────────────────────────┐
│  Agent Assisted 3D                  │
├─────────────────────────────────────┤
│  Prompt:                          [x]│
│  ┌───────────────────────────────┐  │
│  │          (text area)          │  │
│  └───────────────────────────────┘  │
│                                     │
│  [ Send ] [ Cancel ] [ Clear ]      │ (REQ-NODE3D-0010)
│                                     │
│  Status:  Generating... ████████░░  │
│                                     │
│  [ Node Tree ] [ Generated Code ]   │ (REQ-EDITOR-0004 Tabs)
│  ┌───────────────────────────────┐  │
│  │ └─ Node3D                    │  │
│  │    ├─ MeshInstance3D         │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### Dock Controller (`agent_assisted_3d_panel.gd`)

```gdscript
func _on_send_pressed():
    if _current_node:
        _current_node.generate()
        _update_status()

func _on_cancel_pressed():
    if _current_node:
        _current_node.cancel_generation()
        _update_status()

func _on_node_code_updated(code: String):
    code_viewer.text = code

func _update_status():
    var status = _current_node.generation_status
    var generating = (status == AgentAssisted3D.GenerationStatus.GENERATING)
    send_button.disabled = generating
    cancel_button.disabled = not generating
```

---

## Requirements Coverage

| Requirement | Covered By |
|---|---|
| REQ-EDITOR-0002 | `agent_assisted_3d_panel.tscn` dock UI |
| REQ-NODE3D-0010 | "Cancel" button and `_on_cancel_pressed` controller logic |
| REQ-EDITOR-0004 | TabContainer with `Node Tree` and `Generated Code` (CodeEdit) |
