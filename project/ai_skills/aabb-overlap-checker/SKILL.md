# AABB Overlap Checker 2D

A specialized AI skill for checking overlap between two axis-aligned boxes (AABB) in 2D space using Godot's Rectangle2 class.

## Description
This skill provides tools to determine if two rectangular boxes overlap in a 2D plane, which is essential for collision detection, hit testing, and spatial queries in Godot 4 projects.

## Available Tools

### `aabb_checker_tool.gd` - AABB Checker Tool
A dedicated tool that extends `AITool` with methods for:

- **`check_overlap(rect1: Rectangle2, rect2: Rectangle2) -> bool`**
  Checks if two rectangles overlap and returns `true` if they do.

- **`check_overlap_with_margin(rect1: Rectangle2, rect2: Rectangle2, margin: float) -> bool`**
  Checks if two rectangles overlap with an optional margin for padding.

- **`get_overlap_area(rect1: Rectangle2, rect2: Rectangle2) -> Area2`**
  Returns the overlapping area as a `Rectangle2` (empty if no overlap).

## Usage Pattern
Access the tool via `context_node` after activating this skill:

```gdscript
# Get AABB checker tool
var overlap_checker := get_tool("aabb_overlap_checker")

# Check simple overlap
if overlap_checker.check_overlap(rect1, rect2):
    print("Boxes overlap!")

# Check with margin
if not overlap_checker.check_overlap_with_margin(hitbox, obstacle, 5.0):
    print("No collision with margin!")

# Get actual overlap area
var overlap := overlap_checker.get_overlap_area(box_a, box_b)
if overlap.is_inside(Vector2(100, 100)):
    # Point is in the overlapping region
    pass
```

## Rectangle2 Reference
- `Rectangle2.new(pos: Vector2, size: Vector2)` - Create from position and size
- `Rectangle2.new(bottom_left_pos: Vector2, bottom_right_pos: Vector2)` - Create from corners
- `.contains(point: Vector2)` - Check if point is inside the rectangle
- `.has_point(position: Vector2)` - Alias for contains
- `.intersects(other: Area2)` - Check overlap with any Area2
- `Rectangle2.from_rect(rect: Rectangle2, x: float, y: float)` - Offset existing rect

## Example Scene Integration
```gdscript
# In a Node or Control's _process:
func _process(delta: float) -> void:
	var player_hitbox := Rectangle2.from_rect(
		Rectangle2.new(Vector2(50, 100), Vector2(30, 50))
	)
	var obstacle_hitbox := Rectangle2.new(Vector2(60, 80), Vector2(20, 40))
	
	if overlap_checker.check_overlap(player_hitbox, obstacle_hitbox):
		handle_collision()
```
