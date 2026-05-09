# Design Overview

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     Godot Editor                             │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                 AgentAssisted3D Node                    │  │
│  │  ┌──────────────┐  ┌───────────────┐  ┌────────────┐  │  │
│  │  │  Prompt UI   │  │  Textures     │  │  Status    │  │  │
│  │  └──────────────┘  └───────────────┘  └────────────┘  │  │
│  │         │                │               │             │  │
│  │         └────────────────┼───────────────┘             │  │
│  │                        ▼                               │  │
│  │              Generation Pipeline                       │  │
│  │  ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌───────┐  │  │
│  │  │ Prompt  │→│ AI Client │→│ Generator│→│ Runner│→│ Nodes│  │  │
│  │  │ Builder │  │ (OpenAI)  │  │ (GDScript)│  │ (safe)│  │  │
│  │  └─────────┘  └──────────┘  └──────────┘  └───────┘  │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                      AIChat Node                       │  │
│  │  ┌────────────────┐         ┌────────────────────┐     │  │
│  │  │ chat_history   │         │ AI Client (OpenAI) │     │  │
│  │  └────────────────┘         └────────────────────┘     │  │
│  └────────────────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────────────────┤
│                     Plugin Layer                             │
│  plugin.cfg │ ai_assistant.gd │ settings │ dock             │
└──────────────────────────────────────────────────────────────┘
```

## File Structure

```
res://
├── plugin.cfg                              # Plugin manifest
├── ai_assistant.gd                        # Plugin entry point, registers dock & node
├── agent_assisted_3d.gd                  # Custom 3D node class (AIAgentAssisted3D)
├── ai_chat.gd                            # Custom chat node class (AIChat)
├── agent_assisted_3d_panel.tscn          # Editor dock UI scene
├── agent_assisted_3d_panel.gd            # Editor dock UI controller
├── ai_client/
│   ├── ai_client.gd                      # Abstract base / interface
│   └── openai_client.gd                  # OpenAI-compatible API implementation
├── generator/
│   ├── prompt_builder.gd                 # Builds AI prompt from user input + textures
│   ├── script_executor.gd                # Safely loads & runs generated GDScript
│   └── custom_logger.gd                  # Intercepts engine errors
├── settings/
│   └── ai_settings.gd                    # Reads/writes project settings
└── generated/                            # Cache directory for generated .gd/.tscn files
```

## Design Documents

- `0000-overview.md`: Project architecture and implementation roadmap.
- `0001-node3d.md`: Detailed design of the `AIAgentAssisted3D` node.
- `0002-aiintg.md`: AI client and protocol integration details.
- `0003-editor.md`: Editor dock and UX design.
- `0004-persist.md`: File persistence and serialization strategy.
- `0005-safety.md`: Error handling and loop limits.
- `0006-chat.md`: Generic AI chat node (`AIChat`) design.
- `0007-tools.md`: AI tool/function calling system.

## Implementation Order

1. **Plugin scaffolding** - `plugin.cfg`, `ai_assistant.gd`, plugin registration
2. **AI settings** - `settings/ai_settings.gd`, auto-configure project settings
3. **AI client** - `ai_client/` with OpenAI-compatible streaming
4. **Prompt builder** - `generator/prompt_builder.gd` with system prompt
5. **Script executor** - `generator/script_executor.gd` with safety measures
6. **AgentAssisted3D node** - Custom node class with generation pipeline
7. **AIChat node** - Custom chat node for generic AI interaction
8. **Editor dock** - `agent_assitted_3d_panel.tscn` with UI and integration
9. **Persistence** - Cache management, prompt change detection, regeneration
10. **Testing** - Verify with LM Studio, edge cases, error handling

## Requirements Coverage

| Requirement | Covered In |
|---|---|
| REQ-PLGN-0001 | This overview document defines the architecture, file structure, and implementation order for integrating the AI coding agent with Godot 4. |
