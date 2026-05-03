# Persistence Design

## REQ-PERSIST-0001: The result of a successful generation shall be saved to disk

### Storage Location

Generated resources are stored in `res://generated/`, named using the node's name.

```
res://generated/
├── <node_name>.tscn (Scripted Scene Mode)
└── <node_name>.gd   (Node Script Mode)
```

### Save Mechanism

- **Scripted Scene Mode**: The plugin executes the AI's GDScript, takes the returned `Node3D` root, and serializes it to a `.tscn` file using `PackedScene.pack()`.
- **Node Script Mode**: The plugin saves the raw string to a `.gd` file.

---

## REQ-PERSIST-0002: Applying Results

### Scripted Scene Mode
The `AgentAssisted3D` node clears its existing children and instantiates the saved `.tscn` file.

```gdscript
func _apply_scene(path: String):
    # Clear children
    for child in get_children():
        child.queue_free()
    
    # Load and instantiate
    var scene = load(path) as PackedScene
    if scene:
        var instance = scene.instantiate()
        add_child(instance)
        instance.owner = get_tree().edited_scene_root
```

### Node Script Mode
The plugin attaches the saved `.gd` script to a new child node of the `AIAgentAssisted3D` node.

```gdscript
func _apply_script(path: String):
    var script = load(path) as Script
    if script:
        var instance = Node3D.new()
        instance.name = generated_node_name
        instance.set_script(script)
        add_child(instance)
        instance.owner = get_tree().edited_scene_root
```

---

## Requirements Coverage

| Requirement | Covered By |
|---|---|
| REQ-PERSIST-0001 | Direct file save in `res://generated/` after successful generation. |
| REQ-PERSIST-0002 | `load()` and `instantiate()` or `set_script()` for persistence. |
| REQ-PERSIST-0003 | Removal of all automatic background generation triggers. |
