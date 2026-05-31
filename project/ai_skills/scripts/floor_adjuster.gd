@tool
class_name FloorAdjusterSkill
extends "res://addons/ai_assistant/skills/ai_skill_node.gd"

class BoxData:
	var node: Node3D
	var is_csg: bool
	var csg_box: CSGBox3D
	var mesh_instance: MeshInstance3D
	var center: Vector3
	var size: Vector3
	var min_x: float
	var max_x: float
	var min_z: float
	var max_z: float
	
	var delta_min_x: float = 0.0
	var delta_max_x: float = 0.0
	var delta_min_z: float = 0.0
	var delta_max_z: float = 0.0
	
	var wall_min_x: String = ""
	var wall_max_x: String = ""
	var wall_min_z: String = ""
	var wall_max_z: String = ""

func _init() -> void:
	description = "Automatically resize and position floors to meet at the center of separating walls."
	definition = """
		This skill provides a tool to fix imprecise floor placements.
		It extracts floors and walls, and adjusts floor edges so they snap exactly to the middle 
		of any wall that bounds them, eliminating gaps between rooms.
		
		USAGE:
		- To adjust floors: call 'adjust_floors'. You can optionally provide 'target_node_path' for floors and 'walls_node_path' for walls if they are grouped separately.
	"""
	
	tools = [
		{
			"type": "function",
			"function": {
				"name": "adjust_floors",
				"description": "Scans the target node's hierarchy, finds floors and walls, and applies size and position adjustments to floors so they meet at the middle of walls.",
				"parameters": {
					"type": "object",
					"properties": {
						"target_node_path": { "type": "string", "description": "Optional relative path to the node containing floors. Defaults to finding a 'Generated' node or the scene root." },
						"walls_node_path": { "type": "string", "description": "Optional relative path to the node containing walls. Defaults to the scene root." }
					},
					"required": []
				}
			}
		}
	]

func adjust_floors(arguments: Dictionary) -> String:
	var target_path = arguments.get("target_node_path", "")
	var walls_path = arguments.get("walls_node_path", "")
	var scene_root = get_tree().get_edited_scene_root()
	if not scene_root:
		return "Error: No edited scene root found."
		
	var target_node = null
	if target_path != "" and target_path != ".":
		target_node = scene_root.get_node_or_null(target_path)
	else:
		target_node = scene_root
			
	if not target_node:
		return "Error: Could not find target node."
		
	var floors = []
	var local_walls = []
	_extract_boxes(target_node, floors, local_walls)
	
	var walls = []
	var walls_node = null
	
	if walls_path != "" and walls_path != ".":
		walls_node = scene_root.get_node_or_null(walls_path)
		
	if walls_node:
		var dummy_floors = []
		_extract_boxes(walls_node, dummy_floors, walls)
	elif target_node != scene_root:
		var dummy_floors = []
		_extract_boxes(scene_root, dummy_floors, walls)
	else:
		walls = local_walls
	
	if floors.size() == 0:
		return "No floors found to adjust."
		
	var modifications = 0
	
	for f in floors:
		for w in walls:
			if w.size.x > w.size.z:
				# Wall runs along X axis
				if f.max_x > w.min_x and f.min_x < w.max_x:
					var dist_max = abs(f.max_z - w.center.z)
					var dist_min = abs(f.min_z - w.center.z)
					
					if dist_max < w.size.z / 2.0 + 0.5:
						var candidate_delta = w.center.z - f.max_z
						if f.delta_max_z == 0.0 or abs(candidate_delta) < abs(f.delta_max_z):
							f.delta_max_z = candidate_delta
							f.wall_max_z = w.node.name
					
					if dist_min < w.size.z / 2.0 + 0.5:
						var candidate_delta = w.center.z - f.min_z
						if f.delta_min_z == 0.0 or abs(candidate_delta) < abs(f.delta_min_z):
							f.delta_min_z = candidate_delta
							f.wall_min_z = w.node.name
			else:
				# Wall runs along Z axis
				if f.max_z > w.min_z and f.min_z < w.max_z:
					var dist_max = abs(f.max_x - w.center.x)
					var dist_min = abs(f.min_x - w.center.x)
					
					if dist_max < w.size.x / 2.0 + 0.5:
						var candidate_delta = w.center.x - f.max_x
						if f.delta_max_x == 0.0 or abs(candidate_delta) < abs(f.delta_max_x):
							f.delta_max_x = candidate_delta
							f.wall_max_x = w.node.name
							
					if dist_min < w.size.x / 2.0 + 0.5:
						var candidate_delta = w.center.x - f.min_x
						if f.delta_min_x == 0.0 or abs(candidate_delta) < abs(f.delta_min_x):
							f.delta_min_x = candidate_delta
							f.wall_min_x = w.node.name
							
	# Floor to Floor snapping (pass 2: for open-plan areas without walls)
	for f in floors:
		for f2 in floors:
			if f == f2: continue
			
			# Check Z gaps
			if f.max_x > f2.min_x and f.min_x < f2.max_x:
				var gap_z_max = f2.min_z - f.max_z
				var gap_z_min = f2.max_z - f.min_z
				
				# f2 is directly in front of f
				if gap_z_max > 0.001 and gap_z_max < 0.2:
					var shift = gap_z_max / 2.0
					if f.delta_max_z == 0.0:
						f.delta_max_z = shift
						f.wall_max_z = "Floor:" + f2.node.name
						
				# f2 is directly behind f
				if gap_z_min < -0.001 and gap_z_min > -0.2:
					var shift = gap_z_min / 2.0
					if f.delta_min_z == 0.0:
						f.delta_min_z = shift
						f.wall_min_z = "Floor:" + f2.node.name

			# Check X gaps
			if f.max_z > f2.min_z and f.min_z < f2.max_z:
				var gap_x_max = f2.min_x - f.max_x
				var gap_x_min = f2.max_x - f.min_x
				
				if gap_x_max > 0.001 and gap_x_max < 0.2:
					var shift = gap_x_max / 2.0
					if f.delta_max_x == 0.0:
						f.delta_max_x = shift
						f.wall_max_x = "Floor:" + f2.node.name
						
				if gap_x_min < -0.001 and gap_x_min > -0.2:
					var shift = gap_x_min / 2.0
					if f.delta_min_x == 0.0:
						f.delta_min_x = shift
						f.wall_min_x = "Floor:" + f2.node.name
							
	var details = []
	for f in floors:
		if abs(f.delta_min_x) > 0.001 or abs(f.delta_max_x) > 0.001 or abs(f.delta_min_z) > 0.001 or abs(f.delta_max_z) > 0.001:
			modifications += 1
			var new_size_x = f.size.x + f.delta_max_x - f.delta_min_x
			var new_size_z = f.size.z + f.delta_max_z - f.delta_min_z
			var shift_x = (f.delta_max_x + f.delta_min_x) / 2.0
			var shift_z = (f.delta_max_z + f.delta_min_z) / 2.0
			
			var axes = []
			if abs(shift_x) > 0.001 or abs(f.delta_max_x - f.delta_min_x) > 0.001:
				var w_info = []
				if f.wall_min_x != "": w_info.append("min: " + f.wall_min_x)
				if f.wall_max_x != "": w_info.append("max: " + f.wall_max_x)
				var w_str = " (against " + ", ".join(w_info) + ")" if w_info.size() > 0 else ""
				axes.append("X" + w_str)
			if abs(shift_z) > 0.001 or abs(f.delta_max_z - f.delta_min_z) > 0.001:
				var w_info = []
				if f.wall_min_z != "": w_info.append("min: " + f.wall_min_z)
				if f.wall_max_z != "": w_info.append("max: " + f.wall_max_z)
				var w_str = " (against " + ", ".join(w_info) + ")" if w_info.size() > 0 else ""
				axes.append("Z" + w_str)
			details.append("- %s (Adjusted: %s)" % [f.node.name, "; ".join(axes)])
			
			if f.is_csg:
				f.csg_box.size.x = new_size_x
				f.csg_box.size.z = new_size_z
				f.csg_box.global_position.x += shift_x
				f.csg_box.global_position.z += shift_z
			else:
				if f.mesh_instance.mesh is BoxMesh:
					f.mesh_instance.mesh = f.mesh_instance.mesh.duplicate()
					f.mesh_instance.mesh.size.x = new_size_x
					f.mesh_instance.mesh.size.z = new_size_z
					f.node.global_position.x += shift_x
					f.node.global_position.z += shift_z
					
	if modifications == 0:
		return "Adjusted 0 floors."
		
	return "Adjusted %d floors successfully:\n%s" % [modifications, "\n".join(details)]

func _extract_boxes(parent: Node, floors: Array, walls: Array) -> void:
	for child in parent.get_children():
		var handled = false
		if child is Node3D and child.visible:
			var box = null
			var is_csg = false
			var mesh_instance = null
			var is_combiner = false
			
			if child is CSGCombiner3D:
				is_combiner = true
				for c in child.get_children():
					if c is CSGBox3D:
						box = c
						is_csg = true
						break
			elif child is CSGBox3D:
				box = child
				is_csg = true
			elif child is MeshInstance3D and child.mesh is BoxMesh:
				box = child
				mesh_instance = child
				is_csg = false
				
			if box:
				handled = true
				var size = Vector3.ZERO
				var center = child.global_position
				
				if is_csg:
					if is_combiner:
						center = child.to_global(box.position)
					size = box.size
					# For CSG, we need the global scale and rotation
					var global_basis = child.global_transform.basis
					if not is_combiner and box != child:
						global_basis = box.global_transform.basis
						
					var half_size = size / 2.0
					var p1 = global_basis * Vector3(half_size.x, half_size.y, half_size.z)
					var p2 = global_basis * Vector3(half_size.x, half_size.y, -half_size.z)
					var p3 = global_basis * Vector3(-half_size.x, half_size.y, half_size.z)
					var p4 = global_basis * Vector3(-half_size.x, half_size.y, -half_size.z)
					
					var extent_x = max(abs(p1.x), abs(p2.x), abs(p3.x), abs(p4.x))
					var extent_y = max(abs(p1.y), abs(p2.y), abs(p3.y), abs(p4.y))
					var extent_z = max(abs(p1.z), abs(p2.z), abs(p3.z), abs(p4.z))
					
					size = Vector3(extent_x * 2.0, extent_y * 2.0, extent_z * 2.0)
					
				else:
					var aabb = mesh_instance.get_aabb()
					var global_basis = mesh_instance.global_transform.basis
					
					var half_size = aabb.size / 2.0
					var p1 = global_basis * Vector3(half_size.x, half_size.y, half_size.z)
					var p2 = global_basis * Vector3(half_size.x, half_size.y, -half_size.z)
					var p3 = global_basis * Vector3(-half_size.x, half_size.y, half_size.z)
					var p4 = global_basis * Vector3(-half_size.x, half_size.y, -half_size.z)
					
					var extent_x = max(abs(p1.x), abs(p2.x), abs(p3.x), abs(p4.x))
					var extent_y = max(abs(p1.y), abs(p2.y), abs(p3.y), abs(p4.y))
					var extent_z = max(abs(p1.z), abs(p2.z), abs(p3.z), abs(p4.z))
					
					size = Vector3(extent_x * 2.0, extent_y * 2.0, extent_z * 2.0)
					
				var bd = BoxData.new()
				bd.node = child
				bd.is_csg = is_csg
				if is_csg: bd.csg_box = box
				else: bd.mesh_instance = mesh_instance
				
				bd.size = size
				bd.center = center
				bd.min_x = center.x - size.x / 2.0
				bd.max_x = center.x + size.x / 2.0
				bd.min_z = center.z - size.z / 2.0
				bd.max_z = center.z + size.z / 2.0
				
				# Check original local height for floor/wall classification to avoid rotation bugs
				var original_y = size.y
				if not is_csg and mesh_instance.mesh is BoxMesh:
					original_y = mesh_instance.mesh.size.y
				elif is_csg:
					original_y = box.size.y
					
				if original_y < 1.0:
					floors.append(bd)
				elif original_y >= 1.0:
					walls.append(bd)
					
		if not handled:
			_extract_boxes(child, floors, walls)
