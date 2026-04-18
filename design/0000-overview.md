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
├── agent_assisted_3d.gd                  # Custom 3D node class
├── agent_assisted_3d_panel.tscn          # Editor dock UI scene
├── agent_assisted_3d_panel.gd            # Editor dock UI controller
├── ai_client/
│   ├── ai_client.gd                      # Abstract base / interface
│   └── openai_client.gd                  # OpenAI-compatible API implementation
├── generator/
│   ├── prompt_builder.gd                 # Builds AI prompt from user input + textures
│   └── script_executor.gd                # Safely loads & runs generated GDScript
├── settings/
│   └── ai_settings.gd                    # Reads/writes project settings
└── generated/                            # Cache directory for generated .gd files
    └── (dynamic, per-node)
```

## Implementation Order

1. **Plugin scaffolding** - `plugin.cfg`, `ai_assistant.gd`, plugin registration
2. **AI settings** - `settings/ai_settings.gd`, auto-configure project settings
3. **AI client** - `ai_client/` with OpenAI-compatible streaming
4. **Prompt builder** - `generator/prompt_builder.gd` with system prompt
5. **Script executor** - `generator/script_executor.gd` with safety measures
6. **AgentAssisted3D node** - Custom node class with generation pipeline
7. **Editor dock** - `agent_assitted_3d_panel.tscn` with UI and integration
8. **Persistence** - Cache management, prompt change detection, regeneration
9. **Testing** - Verify with LM Studio, edge cases, error handling

## Requirements Coverage

| Requirement | Covered In |
|---|---|
| REQ-PLGN-0001 | This overview document defines the architecture, file structure, and implementation order for integrating the AI coding agent with Godot 4. |
