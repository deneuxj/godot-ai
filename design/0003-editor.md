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
│  Attachments:                       │
│  ┌───────────────────────────────┐  │
│  │ [x] icon.svg  [x] world.tscn  │  │ (REQ-EDITOR-0005)
│  └───────────────────────────────┘  │
│                                     │
│  Your Message:                      │
│  ┌───────────────────────────────┐  │
│  │          (text area)          │  │
│  └───────────────────────────────┘  │
│                                     │
│  [ Attach ] [ Send ] [ Cancel ]     │ (REQ-EDITOR-0005)
│  [ Clear Hist ]                     │
│                                     │
│  Status: Typing...  ████████░░      │
└─────────────────────────────────────┘
```

### Dock Controller (`ai_chat_panel.gd`)

- Detects selection of `AIChat` nodes in the scene tree.
- Binds to `chat_started`, `progress`, and `chat_finished` signals.
- Updates the `HistoryDisplay` in real-time during streaming.
- Manages button enabled/disabled states based on request status.
- **Attachment Handling:**
    - Opens an `EditorFileDialog` for resource selection when "Attach" is clicked.
    - Maintains a local list of paths to be sent with the next message.
    - Renders a list of current attachments with removal ("x") buttons.
    - Passes the list to `AIChat.send_message()` and clears it after sending.
- **Error Recovery:** (REQ-EDITOR-0006)
    - If `chat_error` is emitted, restores the last sent text and attachments from internal state back into the input fields.

---

## Requirements Coverage

| Requirement | Covered By |
|---|---|
| REQ-EDITOR-0002 | `agent_assisted_3d_panel.tscn` dock UI |
| REQ-NODE3D-0011 | Generation mode selector in the dock |
| REQ-NODE3D-0010 | "Cancel" button and `_on_cancel_pressed` controller logic |
| REQ-EDITOR-0004 | TabContainer with `Generated Output` and `Error Log` |
| REQ-EDITOR-0005 | "Attach" button, FileDialog, and attachment list in `ai_chat_panel` |
| REQ-EDITOR-0006 | State restoration in `ai_chat_panel._on_chat_error` |
