# Persistence Design

## REQ-PERSIST-0001: Generated GDScript shall be cached as a `.gd` resource on disk

### Cache Location

Generated scripts are stored in `res://generated/`, organized by node instance:

```
res://generated/
└── <node_instance_id>/
    ├── generation_001.gd
    ├── generation_002.gd
    └── current.gd → symlink to latest
```

### Instance ID

Each `AgentAssisted3D` node gets a unique instance ID on first use:

```gdscript
var _instance_id: String = "":
    get: return _instance_id if _instance_id != "" else _generate_instance_id()

func _generate_instance_id() -> String:
    # Use the node's path in the scene as a stable identifier
    _instance_id = _get_scene_path_hash()
    return _instance_id

func _get_scene_path_hash() -> String:
    var scene_path = get_tree().edited_scene_root.get_path()
    var full_path = scene_path.get_as_string() + "/" + get_path()
    return MD5.hash_text(full_path)
```

### Cache Read/Write

```gdscript
func _get_cache_path() -> String:
    return "res://generated/%s/current.gd" % instance_id

func _has_valid_cache() -> bool:
    var cache_path = _get_cache_path()
    if not ResourceLoader.exists(cache_path):
        return false
    
    var cached_script = load(cache_path) as GDScript
    if cached_script == null:
        return false
    
    # Verify the cached script's prompt hash matches current prompt
    var cached_hash = cached_script.get_meta("prompt_hash", "")
    var current_hash = MD5.hash_text(prompt)
    return cached_hash == current_hash

func _save_cache(script_text: String):
    var cache_dir = "res://generated/%s/" % instance_id
    DirAccess.make_dir_recursive_absolute(cache_dir)
    
    var cache_path = _get_cache_path()
    
    # Create GDScript resource
    var gdscript = GDScript.new()
    gdscript.source_code = script_text
    gdscript.set_meta("prompt_hash", MD5.hash_text(prompt))
    gdscript.set_meta("generated_at", Time.get_datetime_string_from_system())
    
    # Save to disk
    ResourceSaver.save(cache_path, gdscript)
```

---

## REQ-PERSIST-0002: The node tree shall be persisted in the scene file as child nodes

### Approach

Generated nodes are added as direct children of `AgentAssisted3D` using Godot's standard node hierarchy:

```gdscript
func _apply_generated_nodes(nodes: Array[Node]):
    # Clear existing generated children
    clear_generated_nodes()
    
    for child in nodes:
        add_child(child)
        child.set_owner(get_tree().edited_scene_root)
    
    # Save scene to persist
    var scene_path = get_tree().edited_scene_root.scene_file_path
    if scene_path != "":
        save_scene(scene_path)
```

### Scene Persistence

When the user saves the scene (Ctrl+S), Godot's scene serialization writes all child nodes to the `.tscn` file. The generated node tree is saved like any other scene content.

### Loading Restored Nodes

When the scene is reloaded, the child nodes are restored by Godot's scene loader. The `AgentAssisted3D` node's `_ready()` checks for existing children:

```gdscript
func _ready():
    # If children already exist (from scene file), reuse them
    if get_child_count() > 0:
        generation_status = GenerationStatus.SUCCESS
        status_message = "Using cached scene nodes"
        return
    
    # No children - need to generate
    if prompt != "":
        generate()
```

---

## REQ-PERSIST-0003: The cached script shall be reused when the prompt hasn't changed

### Cache Validation

Before calling the AI, the node checks:

```gdscript
func generate():
    # Check cache first
    if _has_valid_cache():
        _load_from_cache()
        return
    
    # Cache invalid or missing - call AI
    _call_ai()
```

### `_has_valid_cache()` checks:

1. Cache file exists at `res://generated/<instance_id>/current.gd`
2. Cache file loads as valid `GDScript` resource
3. Cached `prompt_hash` matches current `prompt` (MD5 hash comparison)

### `_load_from_cache()`:

```gdscript
func _load_from_cache():
    var cache_path = _get_cache_path()
    var cached_script = load(cache_path) as GDScript
    
    if cached_script == null:
        generate()  # Fallback to AI
        return
    
    # Execute cached script to rebuild node tree
    var nodes = await ScriptExecutor.execute_cached(cached_script, self)
    
    for child in nodes:
        add_child(child)
        child.set_owner(get_tree().edited_scene_root)
    
    generation_status = GenerationStatus.SUCCESS
    status_message = "Loaded from cache"
    emit_signal("generation_finished")
```

---

## REQ-PERSIST-0004: The cache shall be invalidated when the prompt changes or force-regenerate is triggered

### Prompt Change Invalidation

In `agent_assisted_3d.gd`:

```gdscript
func _prompt_changed() -> bool:
    var new_hash = MD5.hash_text(prompt)
    if new_hash != _prompt_hash:
        _prompt_hash = new_hash
        return true
    return false

func _on_prompt_changed():
    _invalidate_cache()
    generate()

func _invalidate_cache():
    var cache_path = _get_cache_path()
    if DirAccess.file_exists(cache_path):
        DirAccess.remove_absolute(cache_path)
```

### Force-Regenerate Invalidation

```gdscript
func force_generate():
    _invalidate_cache()
    generate()
```

### Cache Invalidation Summary

| Trigger | Action |
|---|---|
| Prompt changes | `_prompt_changed()` detects hash mismatch → `_invalidate_cache()` → `generate()` |
| Force-regenerate | `force_generate()` → `_invalidate_cache()` → `generate()` |
| Manual cache delete | `_has_valid_cache()` returns false → `generate()` calls AI |

---

## Requirements Coverage

| Requirement | Covered By |
|---|---|
| REQ-PERSIST-0001 | Cache directory structure under `res://generated/`, `.gd` resource save with `ResourceSaver`, prompt hash metadata |
| REQ-PERSIST-0002 | Generated nodes added as direct children with `set_owner()`, Godot scene serialization handles `.tscn` persistence |
| REQ-PERSIST-0003 | `_has_valid_cache()` validates file existence, script validity, and prompt hash match; `_load_from_cache()` rebuilds node tree |
| REQ-PERSIST-0004 | `_invalidate_cache()` deletes cache file on prompt change or force-regenerate; `_has_valid_cache()` returns false after invalidation |
