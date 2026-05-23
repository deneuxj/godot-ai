@tool
extends "res://addons/ai_assistant/skills/ai_skill_node.gd"
class_name ExtractPositionsSkill

# @brief Extract positions and transforms from nodes in the scene tree.
func _init() -> void:
	description = "Extracts position, transform, and CSG data from 3D nodes including walls."
	
	definition = """
You are the ExtractPositionsSkill, specialized in extracting position and transform information from 3D Godot nodes.

## Core Capabilities:
- Extract local position (get_position())
- Extract global/world position (get_global_position())
- Read/write full transform matrices (get_transform/set_transform)
- Read/write global transforms (get_global_transform/set_global_transform)
- Get/set rotation and scale
- Translate nodes by offsets in global space
- Convert between local and global coordinates
- Inspect CSGCombiner3D and its child CSG shapes

## Usage Patterns:
1. To get a node's position in world space: call extract_global_position(node_path) or simply pass a Node directly
2. To move a node: use translate_node(node, offset_vector) for global movement
3. To read full transform info: use get_transform_info(node_path) which returns position, rotation, scale, and basis

## CSG Analysis:
When analyzing walls (CSGCombiner3D):
- Get the CSGCombiner3D node first
- Extract its child CSGBox3D nodes with their positions and dimensions
- Use global_position for world-space analysis

## API Reference:

### extract_global_position(node_or_path) -> Vector3
Returns the global position (world coordinates) of a node. Can accept either a Node or a path string.

### extract_local_position(node_or_path) -> Vector3  
Returns the local position relative to parent.

### get_transform_info(node_or_path) -> Dictionary{position, rotation, scale, basis}
Returns complete transform information as a dictionary.

### set_node_global_position(node, position) -> bool
Sets the global position of a node (world coordinates).

### translate_node(node, offset) -> void
Moves a node by the given offset in world space using global_translate().

### inspect_csg_combiner(csg_node) -> Array[Dictionary]
Extracts information about CSG shapes in a CSGCombiner3D:
- Name of the CSGCombiner
- List of child CSGBox3D nodes with their properties (dimensions, position, etc.)

### find_nodes_by_class(node_path, class_name) -> Array[String]
Finds all nodes matching a specific class in the scene tree.

### convert_local_to_global(local_point, reference_node) -> Vector3
Converts a local coordinate to global/world space using the given node as reference.

### convert_global_to_local(global_point, reference_node) -> Vector3
Converts a global coordinate to local space relative to a node."""

	tools = [
	{
		"type": "function",
		"function": {
			"name": "extract_local_position",
			"description": "Extract the local position relative to parent space.",
			"parameters": {
				"properties": {
					"node_path": {"type": "string", "description": "Path to the node"}
				},
				"type": "object"
			}
		}
	},
	{
		"type": "function",
		"function": {
			"name": "get_transform_info",
			"description": "Get complete transform information (position, rotation, scale, basis) for a node.",
			"parameters": {
				"properties": {
					"node_path": {"type": "string", "description": "Path to the node"}
				},
				"type": "object"
			}
		}
	},
	{
		"type": "function",
		"function": {
			"name": "set_node_global_position",
			"description": "Set the global position (world coordinates) of a node.",
			"parameters": {
				"properties": {
					"node_path": {"type": "string", "description": "Path to the node"},
					"position_x": {"type": "number", "description": "New X coordinate"},
					"position_y": {"type": "number", "description": "New Y coordinate"},
					"position_z": {"type": "number", "description": "New Z coordinate"}
				},
				"type": "object"
			}
		}
	},
	{
		"type": "function",
		"function": {
			"name": "translate_node",
			"description": "Move a node by an offset in world space.",
			"parameters": {
				"properties": {
					"node_path": {"type": "string", "description": "Path to the node"},
					"offset_x": {"type": "number", "description": "Offset X in world space"},
					"offset_y": {"type": "number", "description": "Offset Y in world space"},
					"offset_z": {"type": "number", "description": "Offset Z in world space"}
				},
				"type": "object"
			}
		}
	},
	{
		"type": "function",
		"function": {
			"name": "inspect_csg_combiner",
			"description": "Extract information about CSG shapes in a CSGCombiner3D.",
			"parameters": {
				"properties": {
					"node_path": {"type": "string", "description": "Path to the CSGCombiner3D node"}
				},
				"type": "object"
			}
		}
	},
	{
		"type": "function",
		"function": {
			"name": "convert_coordinates",
			"description": "Convert between local and global coordinates for a point.",
			"parameters": {
				"properties": {
					"node_path": {"type": "string", "description": "Path to the reference node"},
					"point_x": {"type": "number", "description": "X coordinate of the point"},
					"point_y": {"type": "number", "description": "Y coordinate of the point"},
					"point_z": {"type": "number", "description": "Z coordinate of the point"},
					"to_global": {"type": "boolean", "default": true, "description": "Convert local to global (true) or global to local (false)"}
				},
				"type": "object"
			}
		}
	},
	{
		"type": "function",
		"function": {
			"name": "find_nodes_by_class",
			"description": "Find all nodes of a specific class in the scene tree.",
			"parameters": {
				"properties": {
					"class_name": {"type": "string", "description": "Class name to search for (e.g., 'CSGCombiner3D', 'Wall_Generated')"},
					"group_path": {"type": "string", "description": "Optional group path to limit the search"}
				},
				"type": "object"
			}
		}
	}
	]

	# Implementations of the tools:

func extract_global_position(node_or_path: Variant) -> Vector3:
	var node: Node3D = null
	if node_or_path is Node3D:
		node = node_or_path
	else:
		var path := str(node_or_path)
		node = get_node_or_null(path) as Node3D
	
	if node == null:
		push_warning("Node3D not found at path: " + str(node_or_path))
		return Vector3.ZERO
	return node.global_position

func extract_local_position(node_or_path: Variant) -> Vector3:
	var node: Node3D = null
	if node_or_path is Node3D:
		node = node_or_path
	else:
		var path := str(node_or_path)
		node = get_node_or_null(path) as Node3D
	
	if node == null:
		push_warning("Node3D not found at path: " + str(node_or_path))
		return Vector3.ZERO
	return node.position

func get_transform_info(node_or_path: Variant) -> Dictionary:
	var node: Node3D = null
	if node_or_path is Node3D:
		node = node_or_path
	else:
		var path := str(node_or_path)
		node = get_node_or_null(path) as Node3D
	
	if node == null:
		push_warning("Node3D not found at path: " + str(node_or_path))
		return {}
		
	var transform_v := node.transform
	return {
		"position": node.position,
		"rotation": transform_v.basis.get_rotation_quaternion(),
		"scale": transform_v.basis.get_scale(),
		"basis": transform_v.basis
	}

func set_node_global_position(node_or_path: Variant, position_x: float, position_y: float, position_z: float) -> bool:
	var node_to_set: Node3D = null
	if node_or_path is Node3D:
		node_to_set = node_or_path
	else:
		var path := str(node_or_path)
		node_to_set = get_node_or_null(path) as Node3D
	if node_to_set == null:
		push_error("Node3D not found to set position")
		return false
	node_to_set.global_position = Vector3(position_x, position_y, position_z)
	return true

func translate_node(node_or_path: Variant, offset_x: float = 0.0, offset_y: float = 0.0, offset_z: float = 0.0) -> void:
	var node: Node3D = null
	if node_or_path is Node3D:
		node = node_or_path
	else:
		var path := str(node_or_path)
		node = get_node_or_null(path) as Node3D
	if node == null:
		push_error("Node3D not found to translate")
		return
	var offset := Vector3(offset_x, offset_y, offset_z)
	node.global_translate(offset)

func inspect_csg_combiner(node_path: String) -> Array[Dictionary]:
	var csg_node := get_node_or_null(node_path)
	if csg_node == null:
		push_warning("CSGCombiner not found at path: " + node_path)
		return []
	var children := csg_node.get_children()
	var info_list: Array[Dictionary] = []
	for child in children:
		var dict := {}
		if child is CSGBox3D:
			dict["type"] = "CSGBox3D"
			dict["name"] = child.name
			dict["position"] = child.position
			dict["size"] = child.size
		elif child is CSGCombiner3D or child is CSGPolygon3D:
			dict["type"] = child.get_class()
			dict["name"] = child.name
		
		if not dict.is_empty():
			info_list.append(dict)
	return info_list

func find_nodes_by_class(classname: String, group_path: String = "") -> Array[String]:
	var root: Node = get_tree().root if is_inside_tree() else null
	if not group_path.is_empty():
		root = get_node_or_null(group_path)
	
	if root == null:
		return []
		
	var found_nodes := root.find_children("*", classname, true, false)
	var paths: Array[String] = []
	for node in found_nodes:
		paths.append(str(node.get_path()))
	return paths

func convert_coordinates(node_path: String, point_x: float, point_y: float, point_z: float, to_global: bool = true) -> Vector3:
	var point := Vector3(point_x, point_y, point_z)
	if to_global:
		return convert_local_to_global(point, node_path)
	else:
		return convert_global_to_local(point, node_path)

func convert_local_to_global(local_point: Vector3, reference_node: Variant) -> Vector3:
	var node: Node3D = null
	if reference_node is Node3D:
		node = reference_node
	else:
		var path := str(reference_node)
		node = get_node_or_null(path) as Node3D
	if node == null:
		push_warning("Reference Node3D not found for conversion")
		return local_point
	return node.global_transform * local_point

func convert_global_to_local(global_point: Vector3, reference_node: Variant) -> Vector3:
	var node: Node3D = null
	if reference_node is Node3D:
		node = reference_node
	else:
		var path := str(reference_node)
		node = get_node_or_null(path) as Node3D
	if node == null:
		push_warning("Reference Node3D not found for conversion")
		return global_point
	return node.global_transform.affine_inverse() * global_point
