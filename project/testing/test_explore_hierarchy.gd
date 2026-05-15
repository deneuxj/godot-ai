extends SceneTree

func _init():
	print("--- Starting Hierarchy Tool Test ---")
	
	var root = Node3D.new()
	root.name = "TestRoot"
	
	var child1 = Node3D.new()
	child1.name = "Child1"
	root.add_child(child1)
	
	var grandchild = MeshInstance3D.new()
	grandchild.name = "GrandChild"
	child1.add_child(grandchild)
	
	var chat = Node.new()
	chat.name = "AIChat"
	root.add_child(chat)
	
	var ToolScript = load("res://addons/ai_assistant/tools/explore_node_hierarchy_tool.gd")
	var tool = ToolScript.new()
	tool.context_node = chat
	
	# Test 1: List children of parent
	print("\nTest 1: List children of parent (..)")
	var res1 = tool.execute({"command": "list_children", "path": ".."})
	print(res1)
	assert("\"name\":\"Child1\"" in res1)
	assert("\"name\":\"AIChat\"" in res1)
	
	# Test 2: Get node info of parent
	print("\nTest 2: Get node info of parent (..)")
	var res2 = tool.execute({"command": "get_node_info", "path": ".."})
	print(res2)
	assert("\"class\":\"Node3D\"" in res2)
	assert("\"name\":\"TestRoot\"" in res2)
	
	# Test 3: Get tree structure from parent
	print("\nTest 3: Get tree structure from parent (..)")
	var res3 = tool.execute({"command": "get_tree_structure", "path": "..", "depth": 2})
	print(res3)
	assert("\"name\":\"GrandChild\"" in res3)

	# Test 4: List ancestors
	print("\nTest 4: List ancestors (../Child1/GrandChild)")
	var res4 = tool.execute({"command": "list_ancestors", "path": "../Child1/GrandChild"})
	print(res4)
	assert("\"name\":\"Child1\"" in res4)
	assert("\"name\":\"TestRoot\"" in res4)

	# Test 5: Get node info with properties
	print("\nTest 5: Get node info with properties (../Child1/GrandChild)")
	var res5 = tool.execute({"command": "get_node_info", "path": "../Child1/GrandChild"})
	print(res5)
	assert("\"mesh\"" in res5)
	assert("\"skeleton\"" in res5)

	print("\n--- Hierarchy Tool Test Passed! ---")
	root.free()
	quit()
