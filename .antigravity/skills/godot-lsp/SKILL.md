---
name: godot-lsp
description: Validate GDScript files using the Godot language server (LSP on port 6005). Use when checking GDScript scripts for errors, getting type info, or finding symbol references. Requires the Godot editor to be already running with the project open.
---

# GDScript LSP Validator

Use the Godot language server (LSP) to validate scripts and gather code intelligence. This provides accurate diagnostics matching the Godot editor.

**Prerequisite:** The Godot editor must be running with the project open. LSP defaults to `127.0.0.1:6005`.

## Usage

Run the check script using python:

```bash
python3 <skill-dir>/scripts/gdscript_check.py [--project-root /path/to/project] res://path/to/script.gd
```

### Options

- `--project-root`: Path to the directory containing `project.godot`. Defaults to CWD.
- `res://...`: One or more paths to GDScript files to check.

### Exit codes

- `0`: No errors (warnings/hints allowed)
- `1`: Errors or warnings found
- `2`: Connection or protocol error (LSP unavailable)

## When to Use

- After editing GDScript files for quick validation.
- When you need type-level errors, member checks, or function signature verification.
- For code intelligence like symbol references or go-to-definition.

## When NOT to Use

- For C++ or GDExtension code.
- For scene (.tscn) validation (use `godot-validate` instead).
- If the Godot editor is not running.
