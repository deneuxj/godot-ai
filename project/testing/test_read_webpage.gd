extends SceneTree

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Starting Read Webpage Test ---")
	var tool = load("res://addons/ai_assistant/tools/read_webpage_tool.gd").new()
	tool.context_node = self.root
	
	var args = {"url": "https://example.com/"}
	var result = await tool.execute(args)
	
	print("--- Result ---")
	print(result)
	print("--- End Result ---")
	quit()
