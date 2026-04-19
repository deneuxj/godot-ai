---
name: godot-lsp
description: Validate GDScript files using the Godot language server (LSP on port 6005). Use when checking GDScript scripts for errors, getting type info, or finding symbol references. Requires the Godot editor to be already running with the project open.
---

# GDScript LSP Validator

## Purpose

Use the **GDScript language server** (built into the Godot editor) to validate scripts and gather code intelligence. This provides **accurate, full-pipeline diagnostics** — parse errors, type errors, and warnings — that match exactly what the editor sees.

**Prerequisite:** The Godot editor must already be running with the project open. The language server listens on `127.0.0.1:6005`.

## How It Works

The GDScript language server implements the **Language Server Protocol (LSP)** over TCP. This skill uses a helper script to:

1. Connect to the LSP on port 6005
2. Perform the LSP initialization handshake
3. Open each target file as a text document (providing its current on-disk content)
4. Listen for `textDocument/publishDiagnostics` notifications that Godot pushes automatically after each `didOpen`
5. Shutdown cleanly and exit

**Note:** Godot's GDScript LSP does not implement the standard `textDocument/diagnostic` request. Instead it pushes diagnostics via the `textDocument/publishDiagnostics` notification. The helper script is designed to capture these server-pushed messages.

## Running the Check

```bash
python3 <skill-dir>/scripts/gdscript_check.py [--project-root /path/to/project] res://path/to/script.gd
```

Check multiple files at once:

```bash
python3 <skill-dir>/scripts/gdscript_check.py --project-root /path/to/project res://addons/my_plugin/plugin.gd res://scenes/main.gd
```

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | No errors (warnings/hints only, or clean) |
| 1 | Errors or warnings found |
| 2 | Connection or protocol error (LSP unavailable) |

## Interpreting Output

The script outputs a structured report:

```
## Errors & Warnings
- [Error] res://scripts/player.gd:42:15 — Cannot infer type of "x"
- [Warning] res://scripts/utils.gd:8:3 — Unused variable "temp"

## Hints & Information
- [Hint] res://scripts/player.gd:10:0 — Consider using @onready
```

## When to Use This Skill

- **After editing GDScript files** — quick validation without loading the full project
- **When you need type-level errors** — the LSP detects type mismatches, missing members, and incorrect function signatures that a simple parser would miss
- **For code intelligence** — go-to-definition, hover info, and symbol references (future enhancement)
- **When the project has compilation issues** — the LSP works even if the project won't fully load

## When NOT to Use This Skill

- **GDExtension / C++ code** — the LSP only handles GDScript
- **Scene (.tscn) validation** — use the `godot-validate` skill for that
- **When the editor is not running** — the LSP is embedded in the editor, not a standalone server

## File Structure

```
.qwen/skills/godot-lsp/
├── SKILL.md              (this file)
└── scripts/
    └── gdscript_check.py  (helper script)
```

## Notes

- The `--project-root` flag tells the script where to find files on disk for `res://` paths. If the project root is not the current working directory, pass it explicitly.
- The script sends the **current on-disk content** of each file to the LSP. Make sure files are saved before running.
- The LSP may report errors that the editor suppresses or ignores (e.g., deprecation warnings). Use judgment.
- If the connection fails (exit code 2), verify the Godot editor is running with the correct project open.
- The language server defaults to port 6005. If configured differently in the editor, update `HOST` and `PORT` in the script.
