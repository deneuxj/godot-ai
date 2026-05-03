# Validation & Safety Design

## Output Validation

The plugin focuses on **Parse Validation** and **Functional Validation** to ensure the AI's output is usable by Godot.

### GDScript Validation
- Use `GDScript.reload()` to check for syntax/parse errors.
- **Scripted Scene Mode**: The script is instantiated and its `build()` method is executed locally to generate the node hierarchy. This provides immediate feedback on construction errors (missing classes, invalid property names).
- **Node Script Mode**: The script is checked for `extends Node3D` and syntax.

## Safety Note
*Warning: Scripted Scene mode executes AI-generated code in the editor context. Users should only use prompts with trusted LLM backends.*
