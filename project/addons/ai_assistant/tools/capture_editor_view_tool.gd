## CaptureEditorViewTool - Capture the current editor viewport (2D or 3D).
@tool
extends AITool

class_name CaptureEditorViewTool


func _init() -> void:
	super._init("capture_editor_view", "Captures a screenshot of the current editor viewport (2D or 3D) and saves it to a temporary file. Use this to 'see' what is currently visible in the editor.")


func get_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"mode": {
				"type": "string",
				"enum": ["2d", "3d"],
				"description": "Which viewport to capture. Defaults to '3d'."
			}
		}
	}


func execute(arguments: Dictionary) -> String:
	var mode = arguments.get("mode", "3d")
	
	if not context_node:
		return "Error: Context node not available."
		
	var ei = context_node.get("editor_interface")
	if not ei:
		# Try to find it in parent if context_node is just a node in the tree
		var p = context_node.get_parent()
		while p:
			if p.get("editor_interface"):
				ei = p.get("editor_interface")
				break
			p = p.get_parent()
			
	if not ei:
		return "Error: EditorInterface not available. This tool can only be used in the Godot Editor."
	
	var viewport: Viewport = null
	
	if mode == "2d":
		viewport = ei.get_editor_viewport_2d()
	else:
		viewport = ei.get_editor_viewport_3d(0)
		
	if not viewport:
		return "Error: Could not find requested viewport."
		
	# Wait for frame draw to ensure we get latest content.
	# We need to wait in the main thread.
	await context_node.get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	var texture = viewport.get_texture()
	if not texture:
		return "Error: Viewport texture is null."
		
	var image = texture.get_image()
	if not image:
		return "Error: Could not retrieve image from viewport texture."
	
	var save_dir = "res://.gemini/tmp"
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)
		
	var save_path = save_dir + "/snapshot.jpg"
	var err = image.save_jpg(save_path)
	
	if err != OK:
		return "Error: Failed to save screenshot to %s (Error code: %d)" % [save_path, err]
		
	return "Successfully captured %s viewport and saved to: %s. You can now use this image to understand the current scene state. Note: The user can see this image if they look at the file." % [mode, save_path]
