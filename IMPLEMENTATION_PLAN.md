# Implementation Task Plan

## Phase 1: Plugin Scaffolding

1. ~~**Create `plugin.cfg`** — Plugin manifest with name, version, description, and entry point~~ ✅
2. ~~**Create `ai_assistant.gd`** — Plugin entry point extending `EditorPlugin`, implements `_enter_tree()` / `_exit_tree()`, registers the `AgentAssisted3D` node type via `ClassDB`~~ ✅
3. ~~**Register `AgentAssisted3D` as a custom node** — Ensure it appears in the "Add Node" dialog under a plugin category~~ ✅

## Phase 2: AI Settings

4. ~~**Create `settings/ai_settings.gd`** — `AISettings` class with defaults for `base_url`, `api_key`, `model`, `max_tokens`, `timeout_ms`, `system_prompt`~~ ✅
5. ~~**Auto-configure project settings** — `ensure_settings_exist()` called from plugin `_enter_tree()`, saves settings if missing~~ ✅

## Phase 3: AI Client

6. ~~**Create `ai_client/ai_client.gd`** — Abstract base class (`extends Node`) defining `chat()`, `chat_stream()`, `set_endpoint()`, `set_api_key()`, `set_model()`, `set_max_tokens()` interface with method-chaining setters~~ ✅
7. ~~**Create `ai_client/openai_client.gd`** — `OpenAIClient` (`extends AIClient`) implementing `chat()` via `HTTPRequest` POST to `/v1/chat/completions`, parses JSON response for `choices[0].message.content`~~ ✅
8. ~~**Implement `chat_stream()` in `OpenAIClient`** — SSE parsing, emits `progress` signal per chunk, returns concatenated response~~ ✅

## Phase 4: Prompt Builder

9. ~~**Create `generator/prompt_builder.gd`** — `PromptBuilder` class with `DEFAULT_SYSTEM_PROMPT` constant~~ ✅
10. ~~**Implement `build()` method** — Constructs `[system, user]` message array, appends "Visual references attached" when textures present~~ ✅
11. ~~**Handle multimodal content** — Convert `texture_attachments` to base64, build multi-part content array for multimodal models~~ ✅
12. ~~**System prompt override** — Check `ai/openai/system_prompt` project setting, fall back to built-in default~~ ✅
13. ~~**Implement `build_error_correction()`** — Appends error details (message, file, line) and the generated code as a new user message to the conversation history, instructing the AI to correct the script~~ ✅

## Phase 5: Script Executor (Safety)

13. **Create `generator/script_executor.gd`** — `ScriptExecutor` class with `ALLOWED_CLASSES` and `DENIED_METHODS` lists
14. **Implement `_validate_script()`** — Regex-based pre-validation blocking `File`, `FileAccess`, `DirAccess`, `OS.execute`, `HTTPRequest`, `ResourceSaver`, `ResourceLoader`; returns `{"error": String, "file": String, "line": int}`
15. **Implement `execute_with_error()`** — Creates `GDScript` resource, compiles with error capturing, executes `_build_scene()` or `run()`, returns structured error info (null error on success)
16. **Implement `_execute_with_timeout()`** — 10-second timeout via `Timer`, catches errors, returns `{"error": String, "file": String, "line": int}`

## Phase 6: AgentAssisted3D Node

17. **Create `agent_assisted_3d.gd`** — `class_name AgentAssisted3D extends Node3D`
18. **Add exposed properties** — `prompt` (String, multiline setter with hash tracking), `texture_attachments` (Array[Texture2D]), `generation_status` (enum), `status_message`
19. **Add API override properties** — `api_endpoint`, `api_key`, `model` (null = use project settings)
20. **Implement `_ready()` lifecycle** — Check for existing children (scene restore), check cache, auto-generate if prompt is non-empty
21. **Implement generation pipeline with error correction loop `generate()`** — `MAX_RETRIES` (5) loop: PromptBuilder.build() → AIClient.chat() → ScriptExecutor.execute_with_error() → on error, PromptBuilder.build_error_correction() appends error to messages and retries; on success, _save_cache() → status update, emits `generation_started` / `generation_finished` signals
22. **Implement prompt change detection** — `_prompt_changed()` with MD5 hash comparison, `_on_prompt_changed()` invalidates cache and triggers generate
23. **Implement `force_generate()`** — Bypasses prompt hash check, always triggers fresh AI call

## Phase 7: Editor Dock

24. **Create `agent_assisted_3d_panel.tscn`** — UI scene with: title label, `TextEdit` for prompt, attachments container, generate/clear buttons, status row (label + ProgressBar), node tree `Tree` view
25. **Create `agent_assisted_3d_panel.gd`** — Dock controller extending `Control`
26. **Implement selection tracking** — `_on_selection_changed()` connects to editor selection, `_update_for_selected_node()` binds to `AgentAssisted3D` properties
27. **Implement prompt sync** — `TextEdit` ↔ `prompt` property two-way binding via `_on_prompt_text_edit_text_changed()`
28. **Implement generate button** — `_on_generate_pressed()` calls `_current_node.generate()`
29. **Implement progress display** — `_on_node_progress()` updates status label with token count and progress bar
30. **Implement drag & drop** — `_can_drop_data()` / `_drop_data()` for texture attachments (png, jpg, jpeg, bmp, webp)
31. **Implement node tree preview** — `_refresh_node_tree()` populates `Tree` from generated children
32. **Register dock in plugin** — Add dock container in `ai_assistant.gd` `_enter_tree()`, remove in `_exit_tree()`

## Phase 8: Persistence & Caching

33. **Implement cache directory structure** — `res://generated/<instance_id>/` with `current.gd` symlink pattern
34. **Implement instance ID generation** — `_get_scene_path_hash()` using MD5 of scene path + node path
35. **Implement `_save_cache()`** — Creates `GDScript` resource from `script_text`, sets prompt hash metadata, saves via `ResourceSaver`
36. **Implement `_has_valid_cache()`** — Validates file existence, loads as `GDScript`, compares prompt hash metadata
37. **Implement `_load_from_cache()`** — Loads cached script, runs via `ScriptExecutor`, applies nodes as children
38. **Implement `_invalidate_cache()`** — Deletes `current.gd` cache file on prompt change or force-regenerate
39. **Implement scene child persistence** — `_apply_generated_nodes()` adds children with `set_owner()`, auto-saves scene

## Phase 9: Testing & Hardening

40. **Verify with LM Studio** — Test local LLM integration, confirm node tree generation
41. **Test edge cases** — Empty prompt, invalid API response, network timeout, script validation failure
42. **Test cache lifecycle** — Prompt change invalidation, force-regenerate, cross-session reuse
43. **Test safety sandbox** — Verify denied patterns are blocked, timeout enforcement works
44. **Test editor dock UX** — Drag & drop, selection switching, progress feedback, tree preview
45. **Test error correction loop** — Verify compilation errors feed back into conversation, AI produces corrected script on retry, MAX_RETRIES limit enforced, status updates per attempt

---

## Dependencies

| Phase | Depends On |
|-------|-----------|
| 1: Plugin Scaffolding | None (foundation) |
| 2: AI Settings | Phase 1 |
| 3: AI Client | Phase 2 |
| 4: Prompt Builder | Phase 3 |
| 5: Script Executor | None (can parallelize with Phases 3-4) |
| 6: AgentAssisted3D Node | Phases 2, 3, 4, 5 |
| 7: Editor Dock | Phase 6 |
| 8: Persistence & Caching | Phase 6 (overlaps, can develop in parallel once node skeleton exists) |
| 9: Testing & Hardening | Phases 6, 7, 8 |
