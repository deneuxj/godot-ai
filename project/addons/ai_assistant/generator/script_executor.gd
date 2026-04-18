## ScriptExecutor - Safely loads and runs AI-generated GDScript.
##
## Implements sandboxing to restrict AI-generated code to safe
## node manipulation operations only.

class_name ScriptExecutor


static var ALLOWED_CLASSES := [
	"Node3D", "Node", "MeshInstance3D",
	"DirectionalLight3D", "PointLight3D", "Camera3D",
	"CSGBox3D", "CSGCylinder3D", "CSGSphere3D", "CSGCone3D",
	"CSGTorus3D", "CSGCapsule3D",
	"RigidBody3D", "CharacterBody3D", "Area3D",
	"Sprite3D", "Label3D", "Control", "Panel",
	"Mesh", "StandardMaterial3D", "ShaderMaterial",
	"AnimationPlayer", "AnimationTree",
	"AudioStreamPlayer3D", "CPUParticles3D", "GPUParticles3D",
	"SubViewport", "SubViewportContainer",
	"Skeleton3D", "BoneAttachment3D",
	"Marker3D", "Path3D", "PathFollow3D",
	"CollisionShape3D", "RayCast3D",
	"WorldEnvironment", "Environment",
	"Transform3D", "Basis", "Vector3", "Color",
	"PackedScene", "Resource", "RefCounted",
]


static var DENIED_PATTERNS := [
	r"\bFileAccess\b",
	r"\bDirAccess\b",
	r"\bOS\.execute\b",
	r"\bOS\.shell\b",
	r"\bHTTPRequest\b",
	r"\bHTTPClient\b",
	r"\bResourceSaver\b",
	r"\bResourceLoader\.load\b",
	r"\bload\s*\(",
	r"\bsave\s*\(",
]


static func execute(script_text: String, parent: Node3D) -> Array[Node]:
	_validate_script(script_text)

	var gdscript = GDScript.new()
	gdscript.source_code = script_text

	var compile_error = gdscript.compile()
	if compile_error != OK:
		push_error("GDScript compilation error: %d" % compile_error)
		return []

	var instance = gdscript.new()
	if instance == null:
		push_error("Failed to instantiate generated script")
		return []

	var result_nodes: Array[Node] = []

	if instance.has_method("_build_scene"):
		result_nodes = instance._build_scene(parent)
	elif instance.has_method("run"):
		var r = instance.run()
		if r is Array:
			result_nodes = r
	else:
		push_error("Generated script has no _build_scene or run method")

	return result_nodes


static func execute_cached(cached_script: GDScript, parent: Node3D) -> Array[Node]:
	var instance = cached_script.new()
	if instance == null:
		push_error("Failed to instantiate cached script")
		return []

	var result_nodes: Array[Node] = []

	if instance.has_method("_build_scene"):
		result_nodes = instance._build_scene(parent)
	elif instance.has_method("run"):
		var r = instance.run()
		if r is Array:
			result_nodes = r

	return result_nodes


static func _validate_script(script_text: String) -> void:
	for pattern in DENIED_PATTERNS:
		var regex = RegEx.new()
		regex.compile(pattern)
		if regex.search(script_text):
			push_error("Script contains disallowed pattern: " + pattern)
			raise("Script validation failed: disallowed pattern detected")
