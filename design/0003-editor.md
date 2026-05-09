# Editor UX Design

## REQ-EDITOR-0002: Custom editor dock for the AgentAssisted3D node

### Editor Dock Scene (`agent_assisted_3d_panel.tscn`)

```
┌─────────────────────────────────────┐
│  Agent Assisted 3D                  │
├─────────────────────────────────────┤
│  Mode: [ Scripted / Node v ]         │ (REQ-NODE3D-0011)
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
│  [ Generated Output ] [ Error Log ] │ (Tabs)
│  ┌───────────────────────────────┐  │
│  │ func build():                 │  │
│  │    ...                        │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### Dock Controller (`agent_assisted_3d_panel.gd`)

- Handles the `GenerationMode` selection property.
- Syncs the mode selector with the selected `AIAgentAssisted3D` node.
- "Generated Output" tab shows the raw GDScript code.

## AIChat Editor Panel

### Editor Dock Scene (`ai_chat_panel.tscn`)

```
┌─────────────────────────────────────┐
│  AI Chat                            │
├─────────────────────────────────────┤
│  Conversation History:              │
│  ┌───────────────────────────────┐  │
│  │ [User]: Hello                  │  │
│  │ [Assistant]: Hi there!         │  │
│  └───────────────────────────────┘  │
│                                     │
│  Your Message:                      │
│  ┌───────────────────────────────┐  │
│  │          (text area)          │  │
│  └───────────────────────────────┘  │
│                                     │
│  [ Send ] [ Cancel ] [ Clear Hist ] │
│                                     │
│  Status: Typing...  ████████░░      │
└─────────────────────────────────────┘
```

### Dock Controller (`ai_chat_panel.gd`)

- Detects selection of `AIChat` nodes in the scene tree.
- Binds to `chat_started`, `progress`, and `chat_finished` signals.
- Updates the `HistoryDisplay` in real-time during streaming.
- Manages button enabled/disabled states based on request status.

---

## Requirements Coverage

| Requirement | Covered By |
|---|---|
| REQ-EDITOR-0002 | `agent_assisted_3d_panel.tscn` dock UI |
| REQ-NODE3D-0011 | Generation mode selector in the dock |
| REQ-NODE3D-0010 | "Cancel" button and `_on_cancel_pressed` controller logic |
| REQ-EDITOR-0004 | TabContainer with `Generated Output` and `Error Log` |
