@tool
class_name AABBOverlapCheckerTool extends AITool

# Check if two axis-aligned boxes overlap in 2D
static func check_overlap(rect1: Rect2, rect2: Rect2) -> bool:
	"""Check if two rectangles overlap. Returns true if they have any common area."""
	return rect1.intersects(rect2)

# Check overlap with an optional margin/padding
static func check_overlap_with_margin(rect1: Rect2, rect2: Rect2, margin: float = 0.0) -> bool:
	"""Check if two rectangles overlap after applying a margin for padding."""
	if not rect1.intersects(rect2):
		return false
	
	var margin_left: float = -margin / 2
	var margin_top: float = -margin / 2
	var margin_right: float = margin / 2
	var margin_bottom: float = margin / 2
	
	var shrunken_rect1: Rect2 = Rect2(
		Vector2(rect1.position.x + margin_left, rect1.position.y + margin_top),
		Vector2(rect1.size.x + margin_left - margin_right, rect1.size.y + margin_top - margin_bottom)
	)
	
	var shrunken_rect2: Rect2 = Rect2(
		Vector2(rect2.position.x + margin_left, rect2.position.y + margin_top),
		Vector2(rect2.size.x + margin_left - margin_right, rect2.size.y + margin_top - margin_bottom)
	)
	return shrunken_rect1.intersects(shrunken_rect2)

# Get the overlapping area as a Rect2 (empty if no overlap)
static func get_overlap_area(rect1: Rect2, rect2: Rect2) -> Rect2:
	"""Calculate and return the actual overlapping rectangle."""
	if not rect1.intersects(rect2):
		return Rect2()

	var left: float = max(rect1.position.x, rect2.position.x)
	var top: float = max(rect1.position.y, rect2.position.y)
	var right: float = min(rect1.end.x, rect2.end.x)
	var bottom: float = min(rect1.end.y, rect2.end.y)

	return Rect2(left, top, right - left, bottom - top)