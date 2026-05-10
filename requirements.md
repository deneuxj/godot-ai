# Project requirements

## Overview

REQ-PLGN-0001: Integrate a coding agent AI with Godot 4 to assist with scene creation and node hierarchy generation.

## Core Features

### AIAgentAssisted3D Node

REQ-NODE3D-0001: Provide a new 3D node type: `AIAgentAssisted3D`.

REQ-NODE3D-0002: The node shall accept a natural language prompt for scene generation.

REQ-NODE3D-0003: The node shall support attaching multiple textures/images as visual references for the AI.

REQ-NODE3D-0004: The node shall allow selecting between "Scripted Scene" (generates a `build()` method) and "Node Script" (generates a script extending `Node3D`).

REQ-NODE3D-0005: The generated hierarchy or script attachment shall be persisted in the scene file.

### AIChat Node

REQ-CHAT-0001: Provide a new node type: `AIChat` that extends `Node`.

REQ-CHAT-0002: The node shall maintain a conversational history (array of messages).

REQ-CHAT-0003: The node shall provide a method `send_message(prompt: String, attachments: Array[String] = [])` to append a user message, process attachments, and trigger an AI response.

REQ-CHAT-0004: The node shall emit signals for `chat_started`, `progress` (streaming), `chat_finished`, and `chat_error`.

REQ-CHAT-0005: The AI response shall be automatically appended to the conversational history upon successful completion.

REQ-CHAT-0006: The node shall be usable both in the Godot editor (`@tool`) and during gameplay.

REQ-CHAT-0007: The node shall allow overriding API settings (endpoint, key, model, system prompt) via properties, defaulting to project settings.

REQ-CHAT-0008: The node shall provide a `clear_history()` method to reset the conversation.

REQ-CHAT-0009: Ongoing chat requests shall be interruptible via a `cancel()` method.

REQ-CHAT-0010: The `AIChat` node shall support attaching project resources to messages. Initially, this is limited to resources from which image data can be extracted (e.g., Textures).

REQ-CHAT-0011: The content of attached picture resources shall be extracted, base64-encoded, and sent to the AI backend as part of a multi-modal message payload.

### AI Integration

REQ-AIINTG-0001: The plugin shall support **both local and remote** LLM backends.

REQ-AIINTG-0002: The plugin shall use an **OpenAI-compatible API** protocol.

REQ-AIINTG-0003: The AI shall output GDScript code (.gd) which may either construct a scene or implement node logic.

REQ-AIINTG-0005: When a compilation, parse, or load error occurs, the error message shall be appended as a new user message to the conversation history, instructing the AI to correct the output. The AI shall then return a revised version. This process shall repeat until success or the maximum retry limit is reached.

REQ-AIINTG-0004: The following project settings shall be configurable:
  - `ai/connection/base_url` - API endpoint URL
  - `ai/connection/api_key` - Authentication key (optional)
  - `ai/connection/model` - Default model name (general purpose)
  - `ai/connection/router_model` - Fast model for workload analysis
  - `ai/connection/analyst_model` - Complex model for reasoning and planning
  - `ai/connection/technician_model` - Fast model for implementation and tools
  - `ai/generation/max_tokens` - Maximum response tokens
  - `ai/generation/max_retries` - Maximum number of correction attempts
  - `ai/generation/system_prompt` - Custom system prompt (optional override)

REQ-AIINTG-0006: The maximum number of attempts to correct a generated script/scene shall be configurable in the project settings.

REQ-AIINTG-0007: The `AIChat` node shall support an optional workload router:
  - If `use_router` is enabled and no specific `model` override is set on the node, a fast `router_model` shall analyze the latest request.
  - The router shall classify the request as either **Analyst** (complex tasks, planning) or **Technician** (implementation, tool calls).
  - The request shall then be dispatched to the corresponding `analyst_model` or `technician_model`.
  - The selected workload type shall be visible in the user interface.

### Editor UX

REQ-EDITOR-0001: The plugin shall provide real-time progress feedback in the Godot editor during AI processing.

REQ-EDITOR-0002: The plugin shall provide a custom editor dock for the AIAgentAssisted3D node showing:
  - Generation mode selector (Scripted Scene vs. Node Script)
  - Prompt text editor
  - Texture attachment list
  - Send button (triggers generation)
  - Cancel button (interrupts generation)
  - Status/progress indicator

REQ-EDITOR-0003: Generation status shall be tracked as a node property.

REQ-EDITOR-0004: AI-generated GDScript or TSCN code shall be accessible and viewable by the user within the editor dock UI.

REQ-EDITOR-0005: The `AIChat` editor UI shall provide a mechanism (e.g., an attachment button and file dialog) to attach `res://` paths to the current prompt before sending.

### Persistence

REQ-PERSIST-0001: The result of a successful generation shall be saved to disk as a `.tscn` or `.gd` file, typically in `res://generated/`.

REQ-PERSIST-0002: The generated scene shall be instantiated as child nodes, or the script shall be attached to a child node, and this state shall be persisted in the scene file.

REQ-PERSIST-0003: No automatic generation shall occur behind the scenes (e.g., on prompt change or scene load).

### AI Tools

REQ-TOOL-0001: The plugin shall support an extensible tool/function calling system for the AI.

REQ-TOOL-0002: Provide a tool `explore_godot_docs` that allows the AI to:
  - List available classes and global constants.
  - Search for classes, methods, or properties by keyword.
  - Retrieve detailed documentation for a specific class, including its description, properties, and methods.

REQ-TOOL-0003: Provide a tool `explore_project_resources` that allows the AI to:
  - List files and directories in the project.
  - Search for specific resources (scenes, scripts, textures) by name.
  - Retrieve basic metadata or content (for text files) of a specific resource.

REQ-TOOL-0004: The `AIAgentAssisted3D` and `AIChat` nodes shall provide properties to enable or disable specific tools for the AI agent.

REQ-TOOL-0005: Tool execution shall be transparent to the user, with results optionally logged in the console or status area.

REQ-TOOL-0006: Provide a tool `modify_project_resource` that allows the AI to:
  - Create new files or patch existing ones.
  - The tool shall take a path, a target line, the old content, and the new content.
  - For existing files, the tool shall verify that the `old_content` exists near the `target_line`. 
  - If a mismatch occurs, the tool shall return an error instructing the AI to read the file again.
  - For new files, the `old_content` shall be empty and the tool shall create the file at the specified path.

REQ-TOOL-0007: Provide a tool `validate_project_resource` that allows the AI to:
  - Validate any resource in the project (scripts, scenes, resources, etc.).
  - The tool shall take a path to the resource.
  - For scripts, it shall perform parse validation.
  - For scenes and other resources, it shall attempt to load them and check for errors.
  - The tool shall capture and return detailed engine errors and warnings encountered during validation.

## Out of Scope (Future)

REQ-FUTURE-0001: Support for Anthropic/Claude API

REQ-FUTURE-0002: Visual node graph output from AI

REQ-FUTURE-0003: Multi-agent collaboration

REQ-FUTURE-0004: AI-assisted debugging
