# Project Mandate: Godot AI Assistant

## Development workflow
- Development is spec-driven
- Use the requirement-designer skill to create new requirements
- Before starting implementation, check if it's covered by a requirement and a design (see design/ directory)
- Bug fixes and small UI adjustments need not be covered by a requirement
- New implementation must not contradict an existing requirement; if it does, describe conflict and ask how to resolve

## 🏗️ Core Architecture
- **Type:** Godot 4 Editor Plugin (`addons/ai_assistant`).
- **Primary Nodes:**
  - `AIChat` (Node): Handles conversational AI and history management.
- **Tool System:** All AI-callable tools must inherit from `AITool` and be located in `addons/ai_assistant/tools/`.

## 💻 GDScript 2.0 Conventions
- **Static Typing:** Use explicit static typing for all variables and function signatures.
- **Plugin Lifecycle:** Always disconnect global signals (e.g., `EditorSelection`) in `_exit_tree()`.

## 📄 TSCN & Resource Rules
- **TSCN Order:** `[gd_scene]` -> `[ext_resource]` -> `[sub_resource]` -> `[node]`.
- **Dependencies:** All `sub_resource` blocks must be defined *before* they are referenced.
- **Paths:** Node `parent` attributes must be relative to the root and **exclude** the root node's name.

## 🧪 Testing & Validation
- **Headless Testing:** Run tests via CLI: `./godot.sh --headless --path project/ testing/<test_name>.tscn`.
- **Mocking:** Use `MockAIClient` for AI-related tests to avoid live API usage.
- **Validation:** Always use the `validate_project_resource` logic when creating or modifying Godot resources to catch parse/load errors early.

## 🛠️ Tool Development Workflow
When adding a new AI-callable tool, follow these steps:
1. **Create Tool Class:** Inherit from `AITool` in `addons/ai_assistant/tools/`. Define `get_parameters()` and `execute()`.
2. **Name Consistency:** The name passed to `super()` in `_init()` MUST match the name used in prompts and documentation exactly. Avoid leading underscores unless intended for internal use.
3. **Register Tool:** Add the tool to the `match` statement in `AIRequestHandler._execute_tool()` so the engine knows how to instantiate it.
4. **Update PromptBuilder:** Add a toggle parameter to `PromptBuilder.get_tool_definitions()` and update the system prompts (`CHAT_SYSTEM_PROMPT`, etc.) to explain to the AI how to use the new tool.
5. **Update Assistant Nodes:** Add an `@export` boolean toggle to `AIChat.gd` and `AIAgentAssisted3D.gd` to enable/disable the tool.

## 🛠️ Workflows
- **Project Settings:** AI configuration is stored under the `ai/` namespace in Project Settings.
