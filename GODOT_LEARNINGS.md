# Godot 4 & GDScript 2.0 Engineering Learnings

This document summarizes key technical findings and best practices discovered during the development of the Godot AI Assistant plugin.

## 1. GDScript 2.0 Property Setters
- **Always Active:** In Godot 4, property setters are **always triggered**, even when assigning to a variable directly from within the same class. The Godot 3 requirement to use `self.property = value` to trigger a setter has been removed.
- **Implicit self:** assigning to `property` is functionally identical to `self.property`.
- **Recursion Safety:** Assigning a value to the property name *inside* its own setter is treated as direct member access, preventing infinite recursion.

## 2. UI Responsiveness & The Event Loop
- **Synchronous Blocking:** GDScript is single-threaded. If a property change (triggering a UI update) is immediately followed by a heavy synchronous operation (like resource loading or script validation), the UI will not redraw until the operation finishes.
- **Flushing Updates:** To ensure state changes (like "Validating...") are visible, you must yield control back to the engine:
  - `await get_tree().process_frame` flushes the current frame's drawing.
  - `await get_tree().create_timer(0.1).timeout` provides a reliable visual buffer for rapid state transitions.

## 3. TSCN File Format Strictness
The Godot `.tscn` parser is highly sensitive to structure and formatting:
- **Mandatory Order:** `[gd_scene]` -> `[ext_resource]` -> `[sub_resource]` -> `[node]`.
- **Dependency Rule:** All `[sub_resource]` blocks must be defined **before** they are referenced by any `[node]`.
- **Relative Paths:** The `parent` attribute for nodes must be relative to the root and **must not** include the root node's name.
- **Primitive Data:** Use raw integers for enums (e.g., `shading_mode = 2`) and compact, space-less constructors (e.g., `Color(1,1,1,1)`).
- **Comments:** Use semicolon `;` for comments (though the editor may strip them on save).

## 4. Programmatic Error Capture
- **Custom Loggers:** Inheriting from the `Logger` class and registering it via `OS.add_logger()` allows you to programmatically intercept engine-level errors (e.g., TSCN parse failures) that are otherwise inaccessible to GDScript.

## 5. Editor Plugin Best Practices
- **Theme Compliance:** Avoid hardcoded colors. Use `EditorInterface.get_base_control().theme` to fetch native colors like `success_color` or `error_color`.
- **Layout Robustness:**
  - Use `ScrollContainer` as the root of editor docks to handle resizing.
  - Avoid **`Panel`** nodes inside container trees. They have a default `custom_minimum_size` (128x128) and `EXPAND` flags that fight container sizing, often causing layout collapse or overlapping elements.
  - **Alternatives:** Use `MarginContainer` for padding, `PanelContainer` for style-aware backgrounds, or `ColorRect` for simple solid backgrounds.
- **Lifecycle Discipline:** Always disconnect from global editor signals (like `EditorSelection.selection_changed`) in `_exit_tree()` to prevent "ghost" logic and memory leaks.
