## PromptBuilder - Constructs AI prompt from user input and texture attachments.
##
## Builds the [param messages] array passed to [class AIClient.chat()],
## including system prompt, user content, and optional multimodal (image) content.
## Also provides [method build_error_correction] for the error-correction loop.

class_name PromptBuilder


## Default system prompt instructing the AI to generate Godot 4 GDScript scenes.
const DEFAULT_SYSTEM_PROMPT := """\
You are a Godot 4 scene generation assistant.
Given a user prompt and optional visual references,
generate GDScript code that creates a node hierarchy.

Rules:
- Output ONLY valid GDScript code, no markdown fences
- Use Node3D, MeshInstance3D, DirectionalLight3D, etc.
- Set reasonable default properties (position, scale, material)
- Use clear variable names and add helpful comments
- The root node should be a Node3D with the script attached
- Use standard Godot 4 API (no deprecated methods)
- Keep the scene performant and well-organized
"""


## Build a [param messages] array for the AI chat API.
##
## Returns an array of two dictionaries: [code]system[/code] and [code]user[/code] messages.
## If [param textures] is non-empty, the user message uses multimodal content
## (base64-encoded images) instead of plain text.
static func build(user_prompt: String, textures: Array[Texture2D]) -> Array[Dictionary]:
	var system_prompt: String = _get_system_prompt()

	var messages: Array[Dictionary] = [
		{"role": "system", "content": system_prompt},
	]

	if textures.size() > 0:
		# Multimodal: build multi-part content array
		var multimodal_content = _build_multimodal_content(user_prompt, textures)
		messages.append({"role": "user", "content": multimodal_content})
	else:
		# Plain text user message
		var user_content: String = user_prompt
		messages.append({"role": "user", "content": user_content})

	return messages


## Build a multi-part content array for multimodal models.
##
## The first part is the user prompt text. Subsequent parts are base64-encoded
## images extracted from the provided [param textures].
static func _build_multimodal_content(user_prompt: String, textures: Array[Texture2D]) -> Array:
	var content: Array = [
		{"type": "text", "text": user_prompt}
	]

	for texture in textures:
		if not is_instance_valid(texture):
			continue

		var image: Image = _texture_to_image(texture)
		if image.is_empty():
			continue

		# Compress to JPEG for smaller payload; fall back to PNG if JPEG fails.
		var buffer: PackedByteArray = image.save_jpg_to_buffer(0.8)
		var mime_type: String = "image/jpeg"
		if buffer.is_empty():
			mime_type = "image/png"
			buffer = image.save_png_to_buffer()

		if buffer.is_empty():
			continue

		var base64: String = Marshalls.raw_to_base64(buffer)
		content.append({
			"type": "image_url",
			"image_url": {"url": "data:%s;base64,%s" % [mime_type, base64]},
		})

	return content


## Convert a [Texture2D] to an [Image] for base64 encoding.
static func _texture_to_image(texture: Texture2D) -> Image:
	var image: Image = null

	if texture is ImageTexture:
		image = texture.get_image()
	elif texture is CompressedTexture2D:
		image = texture.get_image()
	else:
		# Fallback: try to get the underlying image data
		var img_resource: Variant = texture.get("resource")
		if img_resource is Image:
			image = img_resource
		else:
			var img_format: StringName = texture.get("image_format")
			# Try to create an Image from the texture's internal format
			var size: Vector2i = texture.get_size()
			if size.x > 0 and size.y > 0:
				image = Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, texture.get_data())

	return image


## Get the system prompt, checking the project setting override first.
static func _get_system_prompt() -> String:
	var custom: String = ProjectSettings.get_setting("ai/openai/system_prompt", "")
	if custom != "":
		return custom
	return DEFAULT_SYSTEM_PROMPT


## Append error details to the conversation history for the error-correction loop.
##
## The AI receives the error message, file, line number, and the generated code
## that caused the error, then is instructed to provide a corrected version.
static func build_error_correction(messages: Array[Dictionary], error_result: Dictionary, generated_code: String) -> Array[Dictionary]:
	var fix_instruction := """\
The previous script had the following error:

Error: %s
File: %s
Line: %s

Generated code:
%s

Please provide a corrected version of the script that resolves this error.
Output ONLY valid GDScript code, no markdown fences.
""" % [
	error_result.get("error", "Unknown error"),
	error_result.get("file", "unknown"),
	error_result.get("line", 0),
	generated_code,
]

	messages.append({
		"role": "user",
		"content": fix_instruction,
	})

	return messages
