# Editor UX Design

## REQ-EDITOR-0002: Custom editor dock for the AgentAssisted3D node

### Editor Dock Scene (`agent_assisted_3d_panel.tscn`)

```
┌─────────────────────────────────────┐
│  Agent Assisted 3D                  │
├─────────────────────────────────────┤
│  Mode: [ Scene  v ]               [x]│ (REQ-NODE3D-0011)
│                                     │
│  Prompt:                            │
│  ┌───────────────────────────────┐  │
│  │          (text area)          │  │
│  └───────────────────────────────┘  │
│                                     │
│  [ Send ] [ Cancel ] [ Clear ]      │ (REQ-NODE3D-0010)
│                                     │
│  Status:  Generating... ████████░░  │
│                                     │
│  [ Node Tree ] [ Generated Output ] │ (REQ-EDITOR-0004 Tabs)
│  ┌───────────────────────────────┐  │
│  │ └─ Node3D                    │  │
│  │    ├─ MeshInstance3D         │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### Dock Controller (`agent_assisted_3d_panel.gd`)

- Handles the `GenerationMode` selection property.
- Syncs the mode selector with the selected `AgentAssisted3D` node.
- "Generated Output" tab shows the raw TSCN or GDScript code.

---

## Requirements Coverage

| Requirement | Covered By |
|---|---|
| REQ-EDITOR-0002 | `agent_assisted_3d_panel.tscn` dock UI |
| REQ-NODE3D-0011 | Generation mode selector in the dock |
| REQ-NODE3D-0010 | "Cancel" button and `_on_cancel_pressed` controller logic |
| REQ-EDITOR-0004 | TabContainer with `Node Tree` and `Generated Output` (CodeEdit) |
