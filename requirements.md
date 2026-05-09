# Project requirements

## Overview

REQ-PLGN-0001: Integrate a coding agent AI with Godot 4 to assist with scene creation and node hierarchy generation.

## Core Features

### AIAgentAssisted3D Node

REQ-NODE3D-0001: Provide a new 3D node type: `AIAgentAssisted3D`.

... (existing AIAgentAssisted3D requirements) ...

REQ-NODE3D-0005: The generated hierarchy or script attachment shall be persisted in the scene file.

### AIChat Node

REQ-CHAT-0001: Provide a new node type: `AIChat` that extends `Node`.

REQ-CHAT-0002: The node shall maintain a conversational history (array of messages).

REQ-CHAT-0003: The node shall provide a method `send_message(prompt: String)` to append a user message and trigger an AI response.

REQ-CHAT-0004: The node shall emit signals for `chat_started`, `progress` (streaming), `chat_finished`, and `chat_error`.

REQ-CHAT-0005: The AI response shall be automatically appended to the conversational history upon successful completion.

REQ-CHAT-0006: The node shall be usable both in the Godot editor (`@tool`) and during gameplay.

REQ-CHAT-0007: The node shall allow overriding API settings (endpoint, key, model, system prompt) via properties, defaulting to project settings.

REQ-CHAT-0008: The node shall provide a `clear_history()` method to reset the conversation.

REQ-CHAT-0009: Ongoing chat requests shall be interruptible via a `cancel()` method.

### AI Integration

REQ-AIINTG-0001: The plugin shall support **both local and remote** LLM backends.

REQ-AIINTG-0002: The plugin shall use an **OpenAI-compatible API** protocol.

REQ-AIINTG-0003: The AI shall output GDScript code (.gd) which may either construct a scene or implement node logic.

REQ-AIINTG-0005: When a compilation, parse, or load error occurs, the error message shall be appended as a new user message to the conversation history, instructing the AI to correct the output. The AI shall then return a revised version. This process shall repeat until success or the maximum retry limit is reached.

REQ-AIINTG-0004: The following project settings shall be configurable:
  - `ai/connection/base_url` - API endpoint URL
  - `ai/connection/api_key` - Authentication key (optional)
  - `ai/connection/model` - Model name to use
  - `ai/generation/max_tokens` - Maximum response tokens
  - `ai/generation/max_retries` - Maximum number of correction attempts
  - `ai/generation/system_prompt` - Custom system prompt (optional override)

REQ-AIINTG-0006: The maximum number of attempts to correct a generated script/scene shall be configurable in the project settings.

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

### Persistence

REQ-PERSIST-0001: The result of a successful generation shall be saved to disk as a `.tscn` or `.gd` file, typically in `res://generated/`.

REQ-PERSIST-0002: The generated scene shall be instantiated as child nodes, or the script shall be attached to a child node, and this state shall be persisted in the scene file.

REQ-PERSIST-0003: No automatic generation shall occur behind the scenes (e.g., on prompt change or scene load).

## Out of Scope (Future)

REQ-FUTURE-0001: Support for Anthropic/Claude API

REQ-FUTURE-0002: Visual node graph output from AI

REQ-FUTURE-0003: Multi-agent collaboration

REQ-FUTURE-0004: AI-assisted debugging
