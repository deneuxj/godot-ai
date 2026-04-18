# Project requirements

## Overview

REQ-PLGN-0001: Integrate a coding agent AI with Godot 4 to assist with scene creation and node hierarchy generation.

## Core Features

### AgentAssisted3D Node

REQ-NODE3D-0001: Provide a new 3D node type: `AgentAssisted3D`.

REQ-NODE3D-0002: The node shall be parameterized with a text prompt (multiline text input property).

REQ-NODE3D-0003: Textures can be added as attachments to the prompt for visual context.

REQ-NODE3D-0004: When added to a scene, the node shall use AI to process the prompt and generate a subtree of Godot nodes.

REQ-NODE3D-0008: The generated GDScript shall be syntactically valid and compile without errors.

REQ-NODE3D-0009: If the generated script fails to compile or run, the plugin shall append the error details to the chat history and re-send the request to the AI for correction. This loop shall repeat until the script executes successfully or the maximum retry count is reached.

REQ-NODE3D-0005: The generated hierarchy shall be persisted and reused across editor sessions.

REQ-NODE3D-0006: A new hierarchy shall be generated automatically when the prompt changes.

REQ-NODE3D-0007: The user shall be able to force re-generation with the same prompt via a button in the editor dock.

### AI Integration

REQ-AIINTG-0001: The plugin shall support **both local and remote** LLM backends.

REQ-AIINTG-0002: The plugin shall use an **OpenAI-compatible API** protocol (works with LM Studio, Ollama, OpenAI, etc.).

REQ-AIINTG-0003: The AI shall output GDScript code that programmatically creates the node tree at runtime.

REQ-AIINTG-0005: When a compilation or runtime error occurs, the error message (including file, line number, and description) shall be appended as a new user message to the conversation history, instructing the AI to correct the script. The AI shall then return a revised script. This process shall repeat until success or the maximum retry limit is reached.

REQ-AIINTG-0004: The following project settings shall be configurable:
  - `ai/openai/base_url` - API endpoint URL
  - `ai/openai/api_key` - Authentication key (optional)
  - `ai/openai/model` - Model name to use
  - `ai/openai/max_tokens` - Maximum response tokens
  - `ai/openai/system_prompt` - Custom system prompt (optional override)

### Editor UX

REQ-EDITOR-0001: The plugin shall provide real-time progress feedback in the Godot editor during AI processing.

REQ-EDITOR-0002: The plugin shall provide a custom editor dock for the AgentAssisted3D node showing:
  - Prompt text editor
  - Texture attachment list (drag & drop support)
  - Generate button
  - Status/progress indicator
  - Generated node tree preview

REQ-EDITOR-0003: Generation status shall be exposed as a node property (idle, generating, success, error).

### Caching & Persistence

REQ-PERSIST-0001: Generated GDScript shall be cached as a `.gd` resource on disk.

REQ-PERSIST-0002: The node tree shall be persisted in the scene file as child nodes.

REQ-PERSIST-0003: The cached script shall be reused when the prompt hasn't changed.

REQ-PERSIST-0004: The cache shall be invalidated when the prompt changes or force-regenerate is triggered.

### Safety

REQ-SAFETY-0001: AI-generated GDScript shall run in a sandboxed context:
  - No arbitrary filesystem access
  - No network access
  - Limited to Godot node manipulation APIs only

## Out of Scope (Future)

REQ-FUTURE-0001: Support for Anthropic/Claude API

REQ-FUTURE-0002: Visual node graph output from AI

REQ-FUTURE-0003: Multi-agent collaboration

REQ-FUTURE-0004: AI-assisted debugging
