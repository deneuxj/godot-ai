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

## Step 2: Run Editor Mode in Headless Mode with Early Exit Detection

Run Godot in headless editor mode against the project, then **detect when it signals readiness** and exit early. Godot does not exit on its own after loading — it waits for input. The skill must watch for the completion signal and kill the process.

### 2a. Stream output to a temp file

```bash
tmpfile=$(mktemp)
<godot-path> --headless --path <project-dir> -e 2>&1 | tee "$tmpfile" &
godot_pid=$!
```

### 2b. Watch for the "Editor layout ready" signal

```bash
timeout=60
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if grep -q "Editor layout ready" "$tmpfile" 2>/dev/null; then
        echo "Godot project loaded successfully (editor layout ready)."
        kill $godot_pid 2>/dev/null
        wait $godot_pid 2>/dev/null
        break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

if [ $elapsed -ge $timeout ]; then
    echo "Timeout ($timeout s) reached. Proceeding with captured output."
    kill $godot_pid 2>/dev/null
    wait $godot_pid 2>/dev/null
fi
```

### 2c. Read captured output

```bash
output=$(cat "$tmpfile")
rm -f "$tmpfile"
```

**Key flags:**
- `--headless` — no display server required
- `--path <project-dir>` — points to the directory containing `project.godot`
- `-e` — runs in editor mode (loads plugins, parses scripts, registers classes)
- `2>&1` — captures stderr where all parse errors are emitted

**Completion signal:** `[ DONE ] loading_editor_layout` / `Editor layout ready.` — this means all scripts, plugins, and resources have been loaded and parsed. Errors will have already been emitted in the output by this point.

**Fallback:** If the signal is not seen within 60 seconds, kill the process and proceed with whatever was captured.

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

- **Early exit:** The skill watches for `Editor layout ready` in the output and kills Godot immediately. This avoids relying solely on a timeout.
- **Timeout fallback:** If the signal is not seen within 60 seconds, the process is killed and the captured output is analyzed anyway.
- The `--headless -e` combination triggers full project initialization: plugin loading, script parsing, class registration, and editor layout loading.
- A project without a main scene defined will still load and parse scripts — the "no main scene" message is **not** an error.
- GTK/locale warnings (e.g., `Locale not supported by C library`) are environment warnings, not project errors. Ignore them.
