# Persistence Design

## REQ-PERSIST-0001: The result of a successful generation (GDScript) shall be saved to disk

### Storage Location

Generated scripts are stored in `res://generated/`, named using the node's name or a simple unique identifier if needed to avoid collisions.

```
res://generated/
└── <node_name>_last_generation.gd
```

### Save Mechanism

```gdscript
func _save_generated_script(script_text: String):
    var dir = "res://generated/"
    DirAccess.make_dir_recursive_absolute(dir)
    
    var path = "res://generated/%s_last_generation.gd" % name
    
    var file = FileAccess.open(path, FileAccess.WRITE)
    if file:
        file.store_string(script_text)
        file.close()
```

---

## REQ-PERSIST-0002: The node tree shall be persisted in the scene file as child nodes

### Approach

Generated nodes are added as direct children of `AgentAssisted3D` using Godot's standard node hierarchy. To ensure they are saved with the scene, their owner is set to the scene root.

```gdscript
func _apply_generated_nodes(nodes: Array[Node]):
    # Clear existing generated children
    for child in get_children():
        child.queue_free()
    
    for child in nodes:
        add_child(child)
        child.set_owner(get_tree().edited_scene_root)
```

### Scene Persistence

When the user saves the scene (Ctrl+S), Godot's scene serialization writes all child nodes to the `.tscn` file. The generated node tree is saved like any other scene content.

---

## REQ-PERSIST-0003: No automatic generation shall occur behind the scenes

### Explicit Trigger

Generation only happens when `generate()` is called, which is connected to the "Send" button in the editor dock.

```gdscript
# In AgentAssisted3DPanel.gd
func _on_send_pressed():
    if _current_node:
        _current_node.generate()
```

### Prompt Changes

Changing the `prompt` property in the inspector or dock does NOT trigger generation. The user must click "Send" to commit the prompt and start the AI process.

---

## Requirements Coverage

| Requirement | Covered By |
|---|---|
| REQ-PERSIST-0001 | Simple file save in `res://generated/` after successful generation. |
| REQ-PERSIST-0002 | `set_owner()` call to ensure Godot's scene serialization handles persistence. |
| REQ-PERSIST-0003 | Removal of all automatic `generate()` calls from `_ready()` and property setters. |
