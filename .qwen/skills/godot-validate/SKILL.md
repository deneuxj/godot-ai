---
name: godot-validate
description: Validate a Godot project for load errors without running it. Use when checking GDScript/GDExtension scripts, scenes (.tscn), or the project as a whole for parse errors, missing resources, or configuration issues after edits.
---

# Godot Project Validator

## Purpose

Validates a Godot project for errors **without running it**. Detects script parse errors, missing resources, plugin load failures, and configuration issues. This is a CI/validation step, not a runtime check.

## Prerequisites

- Godot mono editor binary must be available on the system.
- The Godot project directory must contain a valid `project.godot` file.

## Step 1: Locate Godot Binary

Find the Godot editor binary. Common locations:

```bash
# Check for wrapper scripts
ls ~/Godot/godot.sh
ls ~/Godot/godot.sh  # Mono version, runs in editor mode

# Or find the binary directly
find ~/Godot -name 'God_v4.*-stable_linux*' -type f 2>/dev/null
find /opt -name 'Godot*' -type f 2>/dev/null
which godot4 2>/dev/null
which godot 2>/dev/null
```

If a wrapper script (e.g., `godot.sh`) exists, use that — it handles environment setup (e.g., `DOTNET_ROOT`).

## Step 2: Run Editor Mode in Headless Mode

Run Godot in headless editor mode against the project. Use `timeout` to prevent hanging — Godot does not exit on its own after loading (it waits for input).

### Recommended approach (works in all environments)

```bash
timeout 60 <godot-path> --headless --path <project-dir> -e 2>&1
```

This captures all output (stdout + stderr) and exits after 60 seconds if Godot hasn't finished. Godot will emit `[ DONE ] loading_editor_layout` / `Editor layout ready.` within seconds of completing initialization, so the effective runtime is usually well under 10 seconds.

**Key flags:**
- `--headless` — no display server required
- `--path <project-dir>` — points to the directory containing `project.godot`
- `-e` — runs in editor mode (loads plugins, parses scripts, registers classes)
- `2>&1` — captures stderr where all parse errors are emitted
- `timeout 60` — prevents Godot from hanging indefinitely

### Why NOT the background + pipe approach (deprecated)

The following pattern **does not work** in environments where `run_shell_command` is subject to permission restrictions:

```bash
# ❌ DO NOT USE — this is blocked by permission rules
tmpfile=$(mktemp)
<godot-path> --headless --path <project-dir> -e 2>&1 | tee "$tmpfile" &
godot_pid=$!
```

**Reason:** The combination of `&` (background process) + `|` (pipe) + `tee` triggers permission rule denial. Individual components (`mktemp`, `tee`, `&`, `|`) work in isolation, but their combination is blocked.

If you need to capture output to a file for later analysis, use a simple redirect instead:

```bash
# ✅ Works but still requires timeout wrapper
<godot-path> --headless --path <project-dir> -e > /tmp/godot-output.txt 2>&1 &
# Note: output may be empty if the process exits before the redirect is flushed.
# Always prefer the direct timeout approach above.
```

**Completion signal:** `[ DONE ] loading_editor_layout` / `Editor layout ready.` — this means all scripts, plugins, and resources have been loaded and parsed. Errors will have already been emitted in the output by this point.

**Fallback:** The `timeout 60` wrapper handles this automatically. Godot exits with code 124 when killed by timeout.

## Step 3: Capture and Report Errors

Parse the output for error indicators. Look for these patterns:

### Script Parse Errors
```
SCRIPT ERROR: Parse Error: <message>
          at: GDScript::reload (res://<file>:<line>)
ERROR: Failed to load script "<res-path>" with error "Parse error".
```

### Resource Load Errors
```
ERROR: <resource loading failure message>
```

### Plugin Errors
```
ERROR: <plugin-related error>
```

### Extension Errors
```
ERROR: <GDExtension load error>
```

### Warnings (non-fatal, but worth noting)
```
WARNING: <warning message>
```

### Successful Load Indicators
```
[ DONE ] <step-name>
```

## Step 4: Report Results

Summarize findings:

1. **Errors** — list each error with file path, line number, and message
2. **Warnings** — list any warnings found
3. **Status** — `PASS` (no errors) or `FAIL` (one or more errors)

### Output Format

```
## Godot Project Validation Report

**Project:** <project-dir>
**Godot Version:** <version from output>
**Status:** FAIL / PASS

### Errors
1. [res://path/to/file.gd:line] Error message
2. ...

### Warnings
1. ...

### Summary
X error(s), Y warning(s) found.
```

## Notes

- **Timeout approach:** The `timeout 60` wrapper is the recommended method. Godot emits `Editor layout ready` within seconds, so effective runtime is typically under 10 seconds. Godot exits with code 124 when killed by timeout.
- The `--headless -e` combination triggers full project initialization: plugin loading, script parsing, class registration, and editor layout loading.
- A project without a main scene defined will still load and parse scripts — the "no main scene" message is **not** an error.
- GTK/locale warnings (e.g., `Locale not supported by C library`) are environment warnings, not project errors. Ignore them.
- **Do not use** background (`&`) + pipe (`|`) + `tee` together — this combination is blocked by permission rules. Use `timeout` wrapping the command directly instead.
