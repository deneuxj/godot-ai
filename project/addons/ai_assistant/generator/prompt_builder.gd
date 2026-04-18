## PromptBuilder - Constructs AI prompt from user input and texture attachments.

class_name PromptBuilder


static var DEFAULT_SYSTEM_PROMPT := (
	"You are a Godot 4 scene generation assistant.\n"
	"Given a user prompt and optional visual references,\n"
	"generate GDScript code that creates a node hierarchy.\n\n"
	"Rules:\n"
	"- Output ONLY valid GDScript code, no markdown fences\n"
	"- Use Node3D, MeshInstance3D, DirectionalLight3D, etc.\n"
	"- Set reasonable default properties (position, scale, material)\n"
	"- Use clear variable names and add helpful comments\n"
	"- The root node should be a Node3D with the script attached\n"
	"- Use standard Godot 4 API (no deprecated methods)\n"
	"- Keep the scene performant and well-organized\n"
)


static func build(user_prompt: String, textures: Array[Texture2D]) -> Array[Dictionary]:
	var system_prompt = _get_system_prompt()

	var user_content = user_prompt
	if textures.size() > 0:
		user_content += "\n\nVisual references attached below."

	var messages: Array[Dictionary] = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": user_content},
	]

	if textures.size() > 0:
		messages[1]["content"] = _build_multimodal_content(user_content, textures)

	return messages


static func _get_system_prompt() -> String:
	var custom = ProjectSettings.get_setting("ai/openai/system_prompt", "")
	if custom != "":
		return custom
	return DEFAULT_SYSTEM_PROMPT


static func _build_multimodal_content(text: String, textures: Array[Texture2D]) -> Dictionary:
	var content: Array[Dictionary] = [
		{"type": "text", "text": text},
	]

	for texture in textures:
		var base64 = _texture_to_base64(texture)
		if base64 != "":
			content.append({
				"type": "image_url",
				"image_url": {
					"url": "data:image/png;base64," + base64,
				},
			})

	return content


static func _texture_to_base64(texture: Texture2D) -> String:
	if texture is ImageTexture:
		var image = texture.get_image()
		if image == null:
			return ""
		image.save_png("/tmp/_ai_temp.png")
		var file = FileAccess.open("/tmp/_ai_temp.png", FileAccess.READ)
		if file == null:
			return ""
		var bytes = file.get_buffer(file.get_length())
		file.close()
		return Base64.encode(bytes)
	elif texture is CompressedTexture2D:
		var image = texture.get_image()
		if image == null:
			return ""
		image.save_png("/tmp/_ai_temp.png")
		var file = FileAccess.open("/tmp/_ai_temp.png", FileAccess.READ)
		if file == null:
			return ""
		var bytes = file.get_buffer(file.get_length())
		file.close()
		return Base64.encode(bytes)
	return ""
