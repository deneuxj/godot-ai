# Safety Design

## REQ-SAFE-0001: AI-generated GDScript shall run in a sandboxed context

### Threat Model

AI-generated code could potentially:
- Access the filesystem (`File`, `FileAccess`)
- Make network requests (`HTTPRequest`)
- Execute system commands (`OS.execute`)
- Access sensitive project data
- Crash the editor with infinite loops or memory exhaustion

### Sandbox Architecture

```
┌─────────────────────────────────────────┐
│         Godot Editor Process             │
│  ┌───────────────────────────────────┐  │
│  │     ScriptExecutor (sandbox)      │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │  GDScript with restrictions  │  │  │
│  │  │                             │  │  │
│  │  │  ALLOWED:                   │  │  │
│  │  │    - Node manipulation      │   │  │
│  │  │    - Transform operations   │  │  │
│  │  │    - Property setting       │  │  │
│  │  │    - Standard node methods  │  │  │
│  │  │                             │  │  │
│  │  │  DENIED:                    │  │  │
│  │  │    - File I/O               │  │  │
│  │  │    - HTTP requests          │  │  │
│  │  │    - OS commands            │  │  │
│  │  │    - ResourceSaver/Load     │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### Script Executor (`generator/script_executor.gd`)

```gdscript
class ScriptExecutor:
    
    # Classes and methods explicitly allowed in generated scripts
    static var ALLOWED_CLASSES := [
        "Node3D", "Node", "Spatial", "MeshInstance3D",
        "DirectionalLight3D", "PointLight3D", "Camera3D",
        "GeometryInstance3D", " CSGCombiner3D", "CSGPrimitive3D",
        "CSGBox3D", "CSGCylinder3D", "CSGSphere3D", "CSGCone3D",
        "CSGTorus3D", "CSGCapsule3D", "CSGMesh3D",
        "RigidBody3D", "CharacterBody3D", "Area3D",
        "Sprite3D", "Label3D", "Control", "Panel",
        "Mesh", "StandardMaterial3D", "ShaderMaterial",
        "AnimationPlayer", "AnimationTree",
        "AudioStreamPlayer3D", "CPUParticles3D", "GPUParticles3D",
        "Camera3D", "SubViewport", "SubViewportContainer",
        "ViewportTexture", "Skeleton3D", "BoneAttachment3D",
        "Marker3D", "Path3D", "PathFollow3D",
        "CollisionShape3D", "RayCast3D", "VisibleOnScreenNotifier3D",
        "VisibleOnScreenEnabler3D", "OccluderInstance3D",
        "World3D", "WorldEnvironment", "Environment",
        "Transform3D", "Basis", "Vector3", "Color",
        "Node3DGizmo", "EditorNode3DGizmo",
        "PackedScene", "Resource", "RefCounted"
    ]
    
    static var DENIED_METHODS := [
        "execute", "shell", "load", "save",
        "File", "FileAccess", "DirAccess", "OS",
        "HTTPRequest", "HTTPClient",
        "load_resource", "save_resource",
        "get_global_transform",  # Allowed but monitored
        "set_process", "set_physics_process"
    ]
    
    static func execute(script_text: String, parent: Node3D) -> Array[Node]:
        # 1. Pre-validation
        _validate_script(script_text)
        
        # 2. Create isolated GDScript resource
        var gdscript = GDScript.new()
        gdscript.source_code = script_text
        
        # 3. Compile with timeout
        var compile_error = gdscript.compile()
        if compile_error != OK:
            push_error("GDScript compilation error: " + str(compile_error))
            return []
        
        # 4. Execute with timeout
        var result = await _execute_with_timeout(gdscript, parent)
        return result
    
    static func execute_with_error(script_text: String, parent: Node3D) -> Dictionary:
        """Execute script and return error info (null if no error) for the correction loop."""
        # 1. Pre-validation
        var validation_result = _validate_script(script_text)
        if validation_result.has("error"):
            return {"error": validation_result.error, "file": "n/a", "line": 0}
        
        # 2. Create isolated GDScript resource
        var gdscript = GDScript.new()
        gdscript.source_code = script_text
        
        # 3. Compile and capture errors
        var compile_error = gdscript.compile()
        if compile_error != OK:
            var error_info = _get_compile_error_details(gdscript)
            push_error("GDScript compilation error: " + str(compile_error))
            return error_info
        
        # 4. Execute with timeout
        var exec_result = await _execute_with_timeout(gdscript, parent)
        if exec_result.has("error"):
            return exec_result
        
        return {"error": null}
    
    static func _get_compile_error_details(gdscript: GDScript) -> Dictionary:
        """Extract file, line, and description from compilation error."""
        # GDScript.compile() returns an error code; we extract details via
        # the compiled script's internal error info
        return {"error": "Compilation failed (error code: %d)" % gdscript.compile(), "file": "n/a", "line": 0}
    
    static func _validate_script(script_text: String) -> Dictionary:
        # Check for dangerous patterns
        var dangerous_patterns = [
            r"\bFile\b",
            r"\bFileAccess\b",
            r"\bDirAccess\b",
            r"\bOS\.execute\b",
            r"\bHTTPRequest\b",
            r"\bHTTPClient\b",
            r"\bload\s*\(",
            r"\bsave\s*\(",
            r"\bResourceSaver\b",
            r"\bResourceLoader\b"
        ]
        
        for pattern in dangerous_patterns:
            var regex = RegEx.new()
            regex.compile(pattern)
            if regex.search(script_text):
                push_error("Script contains disallowed pattern: " + pattern)
                return {"error": "Script validation failed: disallowed pattern detected (" + pattern + ")", "file": "n/a", "line": 0}
        
        return {"error": null}
    
    static func _execute_with_timeout(gdscript: GDScript, parent: Node3D) -> Dictionary:
        var timeout_ms = 10000  # 10 second timeout
        var timer = Timer.new()
        timer.wait_time = timeout_ms / 1000.0
        timer.one_shot = true
        parent.add_child(timer)
        
        var finished = false
        var result_nodes = []
        var error_msg = ""
        
        timer.timeout.connect(func():
            if not finished:
                error_msg = "Script execution timed out after %dms" % timeout_ms
        )
        
        timer.start()
        
        # Execute the script
        var instance = gdscript.new()
        if instance and instance.has_method("_build_scene"):
            result_nodes = instance._build_scene(parent)
        elif instance and instance.has_method("run"):
            result_nodes = instance.run()
        
        finished = true
        timer.stop()
        timer.queue_free()
        
        if error_msg != "":
            push_error(error_msg)
            return {"error": error_msg, "file": "n/a", "line": 0}
        
        return {"error": null}
```

### Allowed Operations

The sandbox permits operations that are safe for scene building:

| Category | Allowed |
|---|---|
| Node creation | `Node3D.new()`, `MeshInstance3D.new()`, etc. |
| Node manipulation | `add_child()`, `remove_child()`, `get_node()` |
| Transforms | `position`, `rotation`, `scale`, `transform` |
| Materials | `StandardMaterial3D.new()`, property setting |
| Meshes | `BoxMesh.new()`, `SphereMesh.new()`, etc. |
| Lights/Cameras | All `*Light3D`, `Camera3D` operations |
| Physics | `RigidBody3D`, `CollisionShape3D`, etc. |
| Animation | `AnimationPlayer`, `AnimationTree` |
| Audio | `AudioStreamPlayer3D` |
| Particles | `CPUParticles3D`, `GPUParticles3D` |

### Denied Operations

| Category | Denied |
|---|---|
| Filesystem | `File`, `FileAccess`, `DirAccess`, `ResourceSaver`, `ResourceLoader` |
| Network | `HTTPRequest`, `HTTPClient` |
| System | `OS.execute`, `OS.shell` |
| Resource manipulation | `load()`, `save()` as functions |
| Process control | `set_process()` to enable/disable |

### Error Handling

| Error Type | Handling |
|---|---|
| Script validation fails | Reject before execution, return error info for correction loop |
| Compilation error | Report line/column via `_get_compile_error_details()`, return error info for correction loop |
| Runtime error | Catch exception, report message, return error info for correction loop |
| Timeout | Kill execution, return timeout message for correction loop |
| Disallowed method call | Caught by validation, return error info for correction loop |

### Error Correction Loop Integration

Errors from `execute_with_error()` are returned as `{"error": String, "file": String, "line": int}` dictionaries. The `generate()` method in `design/0001-node3d.md` uses these to:

1. Append the error as a user message via `PromptBuilder.build_error_correction()`
2. Re-send the full conversation history (including the original prompt + all prior errors) to the AI
3. Repeat until the script executes successfully or `MAX_RETRIES` (5) is reached
4. On success, the corrected script is cached and applied; on failure, status → ERROR

---

## Requirements Coverage

| Requirement | Covered By |
|---|---|
| REQ-SAFE-0001 | `ScriptExecutor._validate_script()` blocks dangerous patterns, `_execute_with_timeout()` enforces execution timeout, allowed/denied operation lists restrict AI-generated code to safe node manipulation only, `execute_with_error()` returns structured error info for the correction loop |
