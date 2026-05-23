@tool
extends Node

func _ready():
	var LMStudioClient = load("res://addons/ai_assistant/ai_client/lm_studio_client.gd")
	var client = LMStudioClient.new()
	client.set_endpoint("http://localhost:1234")
	add_child(client)
	
	print("Querying LM Studio models...")
	# Small delay to ensure everything is ready
	await get_tree().create_timer(0.5).timeout
	
	var models = await client.get_local_models()
	
	if models.is_empty():
		print("No models found or LM Studio is not reachable at http://localhost:1234")
	else:
		print("Available Models:")
		for m in models:
			print("- Key: ", m.get("key", "N/A"), " | Name: ", m.get("display_name", "N/A"))
	
	get_tree().quit()
