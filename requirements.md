# Project requirements

## Overview

REQ-PLGN-0001: Integrate a coding agent AI with Godot 4 to assist with scene creation and node hierarchy generation.

## Core Features

### AgentAssisted3D Node

REQ-NODE3D-0001: Provide a new 3D node type: `AgentAssisted3D`.

REQ-NODE3D-0002: The node shall be parameterized with a text prompt (multiline text input property).

REQ-NODE3D-0003: Textures can be added as attachments to the prompt for visual context.

REQ-NODE3D-0004: When added to a scene, the node shall use AI to process the prompt and generate either a Godot scene file (.tscn) or a GDScript file (.gd).

REQ-NODE3D-0011: The user shall be able to choose between three generation modes:
  - **Scene**: The AI generates a `.tscn` file which is then instantiated as a child of the `AgentAssisted3D` node.
  - **Scripted Scene**: The AI generates a GDScript that constructs a node hierarchy when executed. The plugin executes this script, captures any runtime errors for the AI correction loop, and saves the resulting successful hierarchy as a `.tscn` file.
  - **Node Script**: The AI generates a `.gd` script which is attached directly to the `AgentAssisted3D` node or a child node.

REQ-NODE3D-0015: In 'Scripted Scene' mode, the generated script shall implement a standard entry point (e.g., a `build()` method) that returns the root of the generated node hierarchy.

REQ-NODE3D-0012: The user shall be able to specify the name of the generated child node via a property.

REQ-NODE3D-0013: The generated GDScript (in Node Script mode) shall be accessible as a Script resource property on the AIAgentAssisted3D node.

REQ-NODE3D-0014: Detailed error messages from the validation loop shall be accessible via a readonly property on the AIAgentAssisted3D node.

REQ-NODE3D-0008: The generated output shall be a syntactically valid Godot resource (.tscn or .gd).

REQ-NODE3D-0009: If the generated output fails to load or parse, the plugin shall append the error details to the chat history and re-send the request to the AI for correction. This loop shall repeat until the resource loads successfully or the maximum retry count is reached.

REQ-NODE3D-0005: The generated hierarchy or script attachment shall be persisted in the scene file.

REQ-NODE3D-0006: Generation shall only be triggered by explicit user action via the "Send" button in the editor dock.

REQ-NODE3D-0007: The user shall be able to trigger re-generation with the same or modified prompt via the "Send" button.

REQ-NODE3D-0010: Ongoing AI generation requests shall be interruptible by the user.

### AI Integration

REQ-AIINTG-0001: The plugin shall support **both local and remote** LLM backends.

REQ-AIINTG-0002: The plugin shall use an **OpenAI-compatible API** protocol.

REQ-AIINTG-0003: The AI shall output either a Godot scene (.tscn) or GDScript code (.gd) depending on the selected mode.

REQ-AIINTG-0005: When a compilation, parse, or load error occurs, the error message shall be appended as a new user message to the conversation history, instructing the AI to correct the output. The AI shall then return a revised version. This process shall repeat until success or the maximum retry limit is reached.

REQ-AIINTG-0004: The following project settings shall be configurable:
  - `ai/openai/base_url` - API endpoint URL
  - `ai/openai/api_key` - Authentication key (optional)
  - `ai/openai/model` - Model name to use
  - `ai/openai/max_tokens` - Maximum response tokens
  - `ai/openai/max_retries` - Maximum number of correction attempts
  - `ai/openai/system_prompt` - Custom system prompt (optional override)

REQ-AIINTG-0006: The maximum number of attempts to correct a generated script/scene shall be configurable in the project settings.

### Editor UX

REQ-EDITOR-0001: The plugin shall provide real-time progress feedback in the Godot editor during AI processing.

REQ-EDITOR-0002: The plugin shall provide a custom editor dock for the AgentAssisted3D node showing:
  - Generation mode selector (Scene vs. Node Script)
  - Prompt text editor
  - Texture attachment list (drag & drop support)
  - Send button (triggers generation)
  - Cancel button (interrupts generation)
  - Status/progress indicator
  - Generated node tree preview

REQ-EDITOR-0003: Generation status shall be exposed as a node property (idle, generating, success, error).

REQ-EDITOR-0004: AI-generated GDScript or TSCN code shall be accessible and viewable by the user within the editor dock UI.

### Persistence

REQ-PERSIST-0001: The result of a successful generation shall be saved to disk as a `.tscn` or `.gd` file in `res://generated/`.

REQ-PERSIST-0002: The generated scene shall be instantiated as child nodes, or the script shall be attached to the node, and this state shall be persisted in the scene file.

REQ-PERSIST-0003: No automatic generation shall occur behind the scenes (e.g., on prompt change or scene load).

## Out of Scope (Future)

REQ-FUTURE-0001: Support for Anthropic/Claude API

REQ-FUTURE-0002: Visual node graph output from AI

REQ-FUTURE-0003: Multi-agent collaboration

REQ-FUTURE-0004: AI-assisted debugging
