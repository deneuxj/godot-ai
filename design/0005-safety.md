# Validation Design (Obsolete)

*Note: The script execution safety requirements (REQ-SAFE-0001) and the corresponding sandboxed ScriptExecutor implementation have been removed as the plugin no longer executes arbitrary AI-generated code. The system now generates static .tscn or .gd files which are loaded by standard Godot mechanisms.*

## Output Validation

Instead of execution safety, the plugin now focuses on **Parse Validation** to ensure the AI's output is usable by Godot.

### TSCN Validation
- Verify the content begins with `[gd_scene` or `[gd_resource`.
- Basic syntax check to ensure Godot can load the file.

### GDScript Validation
- Use `GDScript.reload()` to check for syntax/parse errors without full execution.
- Ensure the script extends the required base class (`Node3D` or similar).
