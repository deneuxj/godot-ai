# Godot Panel Layout Gotcha

## The Problem

`Panel` nodes work correctly as root/viewport-filling nodes but break when nested inside container nodes (VBoxContainer, HBoxContainer, etc.).

## Root Cause

`Panel` has two problematic defaults:

1. **`custom_minimum_size = (128, 128)`** — forces a minimum size regardless of container allocation
2. **`size_flags = EXPAND`** — tries to expand to fill available space, fighting the container's sizing logic

When a Panel is the root of a scene (anchored to fill the viewport), these defaults are harmless because the Panel expands to fill the available space. But when nested inside a container, the container hands the Panel a specific slice of space, and the Panel's internal minimum size + expansion behavior fights with that allocation, causing:

- Layout collapse (containers give zero space to the Panel)
- Overlapping elements (the Panel ignores container boundaries)
- Cut-off labels and invisible inputs

## The Fix

**Do not use `Panel` nodes inside container trees.** Use them only as root/viewport-filling nodes.

For visual grouping inside containers, use:

| Alternative | Purpose |
|---|---|
| `MarginContainer` | Padding around children. No minimum size. |
| `ColorRect` | Solid color background. No minimum size. |
| Nothing | Rely on container separation and theme styling. |

## Example

**Wrong (breaks inside VBoxContainer):**

```
VBoxContainer
├── Panel          ← custom_minimum_size + EXPAND flags fight the VBox
│   └── VBoxContainer
│       └── ...
```

**Correct (use MarginContainer or nothing):**

```
VBoxContainer
├── MarginContainer   ← just padding, no fighting
│   └── VBoxContainer
│       └── ...
```

Or simply:

```
VBoxContainer
├── VBoxContainer     ← no wrapper needed
│   └── ...
```
