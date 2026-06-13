extends SceneTree

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Starting Web Search Test ---")
	var search_tool = load("res://addons/ai_assistant/tools/search_web_tool.gd").new()
	search_tool.context_node = self.root
	
	var args = {"query": "Godot 4 release date"}
	var result = await search_tool.execute(args)
	
	print("--- Web Search Result ---")
	print(result)
	print("--- End Web Search Test ---")
	quit()
