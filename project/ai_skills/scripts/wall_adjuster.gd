@tool
class_name WallAdjusterSkill
extends "res://addons/ai_assistant/skills/ai_skill_node.gd"

class WallData:
	var node: Node3D
	var is_csg: bool
	var csg_box: CSGBox3D
	var mesh_instance: MeshInstance3D
	var start_pos: Vector3
	var end_pos: Vector3
	var dir: Vector3
	var length: float
	var thickness: float
	var delta_start: float = 0.0
	var delta_end: float = 0.0
	var initial_local_start: float = 0.0
	var has_delta_start: bool = false
	var has_delta_end: bool = false

func _init() -> void:
	description = "Automatically adjust wall lengths to connect precisely without gaps or overlaps."
	definition = """
		This skill provides a tool to fix imprecise wall placements in a scene.
		It extracts walls, finds expected 90-degree joins or close parallel contacts,
		and adjusts their lengths so they coincide perfectly without overlaps or gaps.
		The transform matrix of the walls is not altered (except for translation on non-CSG meshes).
		
		USAGE:
		- To adjust all walls in a group: provide 'target_node_path' and leave 'specific_wall_name' empty.
		- To adjust a single wall: provide its name in 'specific_wall_name'. The tool will adjust only that wall with respect to its close neighbors.
	"""
	
	tools = [
		{
			"type": "function",
			"function": {
				"name": "adjust_walls",
				"description": "Scans the target node's hierarchy, finds joins and contacts, and applies length adjustments to the geometries.",
				"parameters": {
					"type": "object",
					"properties": {
						"target_node_path": { "type": "string", "description": "Relative path to the node containing the walls (e.g., 'Walls'). Defaults to finding a 'Walls' node in the scene." },
						"specific_wall_name": { "type": "string", "description": "Optional name of a single wall to adjust against its neighbors. If omitted, adjusts all walls." }
					},
					"required": []
				}
			}
		}
	]

func adjust_walls(arguments: Dictionary) -> String:
	var target_path = arguments.get("target_node_path", "")
	var scene_root = get_tree().get_edited_scene_root()
	if not scene_root:
		return "Error: No edited scene root found."
		
	var target_node = null
	if target_path != "" and target_path != ".":
		target_node = scene_root.get_node_or_null(target_path)
	else:
		target_node = scene_root.find_child("Walls", true, false)
		
	if not target_node:
		return "Error: Could not find target node for walls."
		
	var walls = _extract_walls(target_node)
	if walls.size() == 0:
		return "No walls found to adjust."
		
	var modifications = 0
	var specific_wall_name = arguments.get("specific_wall_name", "")
	
	# Process Joins (Orthogonal)
	for i in range(walls.size()):
		for j in range(i + 1, walls.size()):
			var wa = walls[i]
			var wb = walls[j]
			
			if specific_wall_name != "" and wa.node.name != specific_wall_name and wb.node.name != specific_wall_name:
				continue

			
			var p1 = Vector2(wa.start_pos.x, wa.start_pos.z)
			var d1 = Vector2(wa.dir.x, wa.dir.z).normalized()
			var p2 = Vector2(wb.start_pos.x, wb.start_pos.z)
			var d2 = Vector2(wb.dir.x, wb.dir.z).normalized()
			
			var dot = d1.dot(d2)
			
			if abs(dot) < 0.1: # Orthogonal
				var intersect = _get_intersection(p1, d1, p2, d2)
				if intersect != null:
					var t = intersect.t
					var u = intersect.u
					
					var end_dist_a = min(abs(t), abs(t - wa.length))
					var end_dist_b = min(abs(u), abs(u - wb.length))
					var dist_a = _dist_to_segment(t, wa.length)
					var dist_b = _dist_to_segment(u, wb.length)
					
					# Only process if they actually cross or almost cross
					if dist_a < 0.5 and dist_b < 0.5:
						var is_wa_butt = end_dist_a < 0.5
						var is_wb_butt = end_dist_b < 0.5
						
						if is_wa_butt and is_wb_butt:
							# L-corner. Make WA the outer, WB the inner.
							if t > wa.length / 2.0:
								var diff = (t + wb.thickness / 2.0) - wa.length
								if abs(diff) < 1.0 and (not wa.has_delta_end or abs(diff) < abs(wa.delta_end)):
									wa.delta_end = diff; wa.has_delta_end = true
							else:
								var diff = (t - wb.thickness / 2.0)
								if abs(diff) < 1.0 and (not wa.has_delta_start or abs(diff) < abs(wa.delta_start)):
									wa.delta_start = -diff; wa.has_delta_start = true
								
							if u > wb.length / 2.0:
								var diff = (u - wa.thickness / 2.0) - wb.length
								if abs(diff) < 1.0 and (not wb.has_delta_end or abs(diff) < abs(wb.delta_end)):
									wb.delta_end = diff; wb.has_delta_end = true
							else:
								var diff = (u + wa.thickness / 2.0)
								if abs(diff) < 1.0 and (not wb.has_delta_start or abs(diff) < abs(wb.delta_start)):
									wb.delta_start = -diff; wb.has_delta_start = true
						elif is_wa_butt:
							# T-junction, WA is butt.
							if t > wa.length / 2.0:
								var diff = (t - wb.thickness / 2.0) - wa.length
								if abs(diff) < 1.0 and (not wa.has_delta_end or abs(diff) < abs(wa.delta_end)):
									wa.delta_end = diff; wa.has_delta_end = true
							else:
								var diff = (t + wb.thickness / 2.0)
								if abs(diff) < 1.0 and (not wa.has_delta_start or abs(diff) < abs(wa.delta_start)):
									wa.delta_start = -diff; wa.has_delta_start = true
						elif is_wb_butt:
							# T-junction, WB is butt.
							if u > wb.length / 2.0:
								var diff = (u - wa.thickness / 2.0) - wb.length
								if abs(diff) < 1.0 and (not wb.has_delta_end or abs(diff) < abs(wb.delta_end)):
									wb.delta_end = diff; wb.has_delta_end = true
							else:
								var diff = (u + wa.thickness / 2.0)
								if abs(diff) < 1.0 and (not wb.has_delta_start or abs(diff) < abs(wb.delta_start)):
									wb.delta_start = -diff; wb.has_delta_start = true
							
			elif abs(dot) > 0.99: # Parallel
				# Check collinearity
				var perp = Vector2(-d1.y, d1.x)
				var perp_dist = abs((p2 - p1).dot(perp))
				if perp_dist < 0.2:
					# Check if ends are close
					var proj_b_start = (p2 - p1).dot(d1)
					var proj_b_end = proj_b_start + d2.dot(d1) * wb.length
					
					var a_end = wa.length
					var a_start = 0.0
					
					if abs(proj_b_start - a_end) < 0.5:
						var mid = (a_end + proj_b_start) / 2.0
						var diff_a = mid - a_end
						if not wa.has_delta_end or abs(diff_a) < abs(wa.delta_end):
							wa.delta_end = diff_a; wa.has_delta_end = true
						
						if d2.dot(d1) > 0:
							var diff_b = -(mid - proj_b_start)
							if not wb.has_delta_start or abs(diff_b) < abs(wb.delta_start):
								wb.delta_start = diff_b; wb.has_delta_start = true
						else:
							var diff_b = proj_b_start - mid
							if not wb.has_delta_end or abs(diff_b) < abs(wb.delta_end):
								wb.delta_end = diff_b; wb.has_delta_end = true
					elif abs(proj_b_end - a_start) < 0.5:
						var mid = (a_start + proj_b_end) / 2.0
						var diff_a = -(mid - a_start)
						if not wa.has_delta_start or abs(diff_a) < abs(wa.delta_start):
							wa.delta_start = diff_a; wa.has_delta_start = true
						
						if d2.dot(d1) > 0:
							var diff_b = mid - proj_b_end
							if not wb.has_delta_end or abs(diff_b) < abs(wb.delta_end):
								wb.delta_end = diff_b; wb.has_delta_end = true
						else:
							var diff_b = -(proj_b_end - mid)
							if not wb.has_delta_start or abs(diff_b) < abs(wb.delta_start):
								wb.delta_start = diff_b; wb.has_delta_start = true
							
	# Apply modifications
	for w in walls:
		if abs(w.delta_start) > 0.001 or abs(w.delta_end) > 0.001:
			modifications += 1
			var new_length = w.length + w.delta_start + w.delta_end
			
			if w.is_csg:
				w.csg_box.size.x = new_length
				w.csg_box.position.x = w.initial_local_start - w.delta_start + new_length / 2.0
			else:
				if w.mesh_instance.mesh is BoxMesh:
					w.mesh_instance.mesh = w.mesh_instance.mesh.duplicate()
					w.mesh_instance.mesh.size.x = new_length
					# Translate the mesh instance node to keep the start anchor correct
					# The center shifted by (delta_end - delta_start) / 2.0 in local X
					var shift_local = (w.delta_end - w.delta_start) / 2.0
					w.node.global_position += w.node.global_transform.basis.x.normalized() * shift_local
					
	return "Adjusted %d walls successfully." % modifications

func _extract_walls(parent: Node) -> Array:
	var walls = []
	for child in parent.get_children():
		if child is Node3D and child.visible:
			var wd = WallData.new()
			wd.node = child
			
			if child is CSGCombiner3D or child is CSGBox3D:
				var box = child as CSGBox3D
				if box == null:
					for c in child.get_children():
						if c is CSGBox3D:
							box = c
							break
				if box:
					wd.is_csg = true
					wd.csg_box = box
					wd.length = box.size.x
					wd.thickness = box.size.z
					wd.initial_local_start = box.position.x - box.size.x/2.0
					var local_start = Vector3(wd.initial_local_start, box.position.y, box.position.z)
					var local_end = Vector3(box.position.x + box.size.x/2.0, box.position.y, box.position.z)
					wd.start_pos = child.to_global(local_start)
					wd.end_pos = child.to_global(local_end)
					wd.start_pos.y = child.global_position.y
					wd.end_pos.y = child.global_position.y
					wd.dir = (wd.end_pos - wd.start_pos).normalized()
					if wd.dir.length_squared() < 0.1:
						wd.dir = child.global_transform.basis.x.normalized()
					walls.append(wd)
			elif child is MeshInstance3D and child.mesh is BoxMesh:
				wd.is_csg = false
				wd.mesh_instance = child
				wd.length = child.mesh.size.x
				wd.thickness = child.mesh.size.z
				var local_start = Vector3(-wd.length/2.0, 0, 0)
				var local_end = Vector3(wd.length/2.0, 0, 0)
				wd.start_pos = child.to_global(local_start)
				wd.end_pos = child.to_global(local_end)
				wd.start_pos.y = child.global_position.y
				wd.end_pos.y = child.global_position.y
				wd.dir = (wd.end_pos - wd.start_pos).normalized()
				if wd.dir.length_squared() < 0.1:
					wd.dir = child.global_transform.basis.x.normalized()
				walls.append(wd)
	return walls

func _get_intersection(p1: Vector2, d1: Vector2, p2: Vector2, d2: Vector2):
	var det = d1.x * d2.y - d1.y * d2.x
	if abs(det) < 0.001:
		return null
	var t = ((p2.x - p1.x) * d2.y - (p2.y - p1.y) * d2.x) / det
	var u = ((p2.x - p1.x) * d1.y - (p2.y - p1.y) * d1.x) / det
	return {"t": t, "u": u}

func _dist_to_segment(t: float, L: float) -> float:
	if t < 0: return -t
	if t > L: return t - L
	return 0.0
