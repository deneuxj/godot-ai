## PromptBuilder - Constructs AI prompt from user input and texture attachments.
##
## Builds the [param messages] array passed to [class AIClient.chat()],
## including system prompt, user content, and optional multimodal (image) content.
## Also provides [method build_error_correction] for the error-correction loop.

class_name PromptBuilder


## System prompt for generating Godot .tscn files.
const SCENE_SYSTEM_PROMPT := """\
You are a Godot 4 scene generator assistant.
Given a user prompt and optional visual references,
output a raw Godot 4 .tscn file content.

Rules:
- Output valid .tscn content. You MAY use markdown code blocks (```tscn ... ```).
- Use [gd_scene ...], [node ...], [sub_resource ...], and [resource ...] tags correctly.
- The root node should be a Node3D.
- Include standard properties (mesh, material, transform).
- Ensure all resources referenced are defined or use built-in types.
- Do NOT output any explanation unless it's outside the code block.
"""

## System prompt for generating Godot .gd scripts.
const NODE_SCRIPT_SYSTEM_PROMPT := """\
You are a Godot 4 GDScript generator assistant.
Given a user prompt and optional visual references,
output a raw GDScript that extends Node3D.

Rules:
- Output valid GDScript code. You MAY use markdown code blocks (```gdscript ... ```).
- The script MUST start with 'extends Node3D'.
- Use clear variable names and add helpful comments.
- Use standard Godot 4 API (no deprecated methods).
- Focus on implementing the specific logic requested (e.g., animation, interaction).
- Do NOT output any explanation unless it's outside the code block.
"""


## Build a [param messages] array for the AI chat API.
##
## Returns an array of dictionaries: [code]system[/code] and [code]user[/code] messages.
## [param mode] corresponds to [enum AIAgentAssisted3D.GenerationMode].
static func build(user_prompt: String, textures: Array[Texture2D], mode: int) -> Array[Dictionary]:
	var system_prompt: String = _get_system_prompt(mode)

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
static func _build_multimodal_content(user_prompt: String, textures: Array[Texture2D]) -> Array:
	var content: Array = [
		{"type": "text", "text": user_prompt}
	]

	for texture in textures:
		if not is_instance_valid(texture):
			continue

		var image: Image = _texture_to_image(texture)
		if image == null or image.is_empty():
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
	if texture is ImageTexture or texture is CompressedTexture2D:
		return texture.get_image()
	
	# Fallback: try to get the underlying image data
	var img_resource: Variant = texture.get("resource")
	if img_resource is Image:
		return img_resource as Image
	
	return null


## Get the system prompt, checking the project setting override first.
static func _get_system_prompt(mode: int) -> String:
	var custom: String = ProjectSettings.get_setting("ai/openai/system_prompt", "")
	if custom != "":
		return custom
	
	# Enum mapping (must match AIAgentAssisted3D.GenerationMode)
	if mode == 0: # SCENE
		return SCENE_SYSTEM_PROMPT
	else: # NODE_SCRIPT
		return NODE_SCRIPT_SYSTEM_PROMPT


## Append error details to the conversation history for the error-correction loop.
static func build_error_correction(messages: Array[Dictionary], error_result: Dictionary, last_content: String) -> Array[Dictionary]:
	# Add the AI's previous (erroneous) response as an assistant message.
	messages.append({
		"role": "assistant",
		"content": last_content,
	})

	# Add the validation error and fix instruction as a user message.
	var fix_instruction := """\
error:
%s
""" % error_result.get("error", "Unknown error")

	messages.append({
		"role": "user",
		"content": fix_instruction,
	})

	return messages
