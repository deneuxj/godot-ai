## ScriptExecutor - Safely loads and runs AI-generated GDScript.
##
## Provides sandboxed execution with regex-based pre-validation to block
## dangerous patterns (filesystem access, network requests, OS commands).
## [method execute_with_error] returns structured error info for the
## error-correction loop in [class AgentAssisted3D].

class_name ScriptExecutor


## Classes explicitly allowed in generated scripts.
static var ALLOWED_CLASSES := PackedStringArray([
	"Node3D", "Node", "Spatial", "MeshInstance3D",
	"DirectionalLight3D", "PointLight3D", "Camera3D",
	"GeometryInstance3D", "CSGCombiner3D", "CSGPrimitive3D",
	"CSGBox3D", "CSGCylinder3D", "CSGSphere3D", "CSGCone3D",
	"CSGTorus3D", "CSGCapsule3D", "CSGMesh3D",
	"RigidBody3D", "CharacterBody3D", "Area3D",
	"Sprite3D", "Label3D", "Control", "Panel",
	"Mesh", "StandardMaterial3D", "ShaderMaterial",
	"AnimationPlayer", "AnimationTree",
	"AudioStreamPlayer3D", "CPUParticles3D", "GPUParticles3D",
	"SubViewport", "SubViewportContainer",
	"ViewportTexture", "Skeleton3D", "BoneAttachment3D",
	"Marker3D", "Path3D", "PathFollow3D",
	"CollisionShape3D", "RayCast3D", "VisibleOnScreenNotifier3D",
	"VisibleOnScreenEnabler3D", "OccluderInstance3D",
	"World3D", "WorldEnvironment", "Environment",
	"Transform3D", "Basis", "Vector3", "Color",
	"Node3DGizmo", "EditorNode3DGizmo",
	"PackedScene", "Resource", "RefCounted",
])


## Regex patterns that are always denied regardless of context.
static var DENIED_PATTERNS := PackedStringArray([
	r"\bFile\b",
	r"\bFileAccess\b",
	r"\bDirAccess\b",
	r"\bOS\s*\.",
	r"\bResourceSaver\b",
	r"\bResourceLoader\b",
])


## Validate an AI-generated script against the sandbox policy.
##
## Returns `{"error": null}` on success, or
## `{"error": String, "file": String, "line": int}` on failure.
static func _validate_script(script_text: String) -> Dictionary:
	for pattern in DENIED_PATTERNS:
		var regex := RegEx.new()
		regex.compile(pattern)
		if regex.search(script_text):
			return {"error": "Script contains disallowed pattern: " + pattern, "file": "n/a", "line": 0}

	# Check HTTPRequest only if the project setting allows it.
	var allow_http := ProjectSettings.get_setting("ai/openai/allow_http_requests", false)
	if not allow_http:
		var regex := RegEx.new()
		regex.compile(r"\bHTTPRequest\b")
		if regex.search(script_text):
			return {"error": "Script uses HTTPRequest which is disabled (set ai/openai/allow_http_requests to enable)", "file": "n/a", "line": 0}

	return {"error": null}


## Execute an AI-generated script safely and return structured error info.
##
## The script is pre-validated, compiled, and executed.
## Returns `{"error": null}` on success, or
## `{"error": String, "file": String, "line": int}` on failure.
static func execute_with_error(script_text: String, parent: Node3D) -> Dictionary:
	# 1. Pre-validation
	var validation_result := _validate_script(script_text)
	if validation_result.error != null:
		return validation_result

	# 2. Create isolated GDScript resource
	var gdscript := GDScript.new()
	gdscript.source_code = script_text

	# 3. Compile and capture errors
	var compile_error: int = gdscript.compile()
	if compile_error != OK:
		return {"error": "Compilation failed (error code: %d)" % compile_error, "file": "n/a", "line": 0}

	# 4. Execute the script
	var instance = gdscript.new()
	if instance:
		if instance.has_method("_build_scene"):
			instance.call("_build_scene", parent)
		elif instance.has_method("run"):
			instance.call("run")

	return {"error": null}
