---
name: godot-validate
description: Validate a Godot project for load errors (scripts, scenes, resources) without running it. Use when checking for parse errors, missing resources, or configuration issues after edits.
---

# Godot Project Validator

Validates a Godot project for errors without running it. Detects script parse errors, missing resources, plugin failures, and configuration issues.

## Prerequisites

- Godot editor binary must be available.
- Project must contain `project.godot`.

## Validation Procedure

Run Godot in headless editor mode with a timeout.

```bash
timeout 15 <godot-path> --headless --path <project-dir> -e 2>&1
```

### Key Flags

- `--headless`: No display server required.
- `--path <project-dir>`: Path to directory with `project.godot`.
- `-e`: Editor mode (loads plugins, parses scripts, registers classes).
- `2>&1`: Capture stderr where parse errors are emitted.
- `timeout 15`: Prevents hanging; Godot doesn't exit automatically after loading.

## Error Identification

Parse the output for these patterns:

- **Script Errors:** `SCRIPT ERROR: Parse Error: ...` or `Failed to load script ...`
- **Resource Errors:** `ERROR: ...` (e.g., missing dependencies)
- **Plugin/Extension Errors:** `ERROR: ...` related to loading GDExtensions or plugins.

**Completion Signal:** Look for `[ DONE ] loading_editor_layout` or `Editor layout ready.`

## When to Use

- To verify project integrity after large refactors or renaming files.
- To catch scene dependency errors or script parse errors that LSP might miss.
- As a pre-commit or CI-like validation step.

## Notes

- Ignore GTK/locale warnings.
- "No main scene" is not an error.
- Do NOT use backgrounding (`&`) with pipes (`|`) as it may be restricted; use the `timeout` approach instead.
