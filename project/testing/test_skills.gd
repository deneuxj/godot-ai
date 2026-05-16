@tool
extends SceneTree

func _init():
	print("--- AI Skill System Tests (Node-Based) ---")
	
	var AIChatClass = load("res://addons/ai_assistant/ai_chat.gd")
	var AISkillNodeScript = load("res://addons/ai_assistant/skills/ai_skill_node.gd")
	var SkillCreatorNodeClass = load("res://addons/ai_assistant/skills/skill_creator_node.gd")
	var AIRequestHandlerClass = load("res://addons/ai_assistant/ai_client/ai_request_handler.gd")
	var PromptBuilderClass = load("res://addons/ai_assistant/generator/prompt_builder.gd")
	
	if not AIChatClass: _fail("Failed to load AIChatClass"); return
	if not AISkillNodeScript: _fail("Failed to load AISkillNodeScript"); return
	if not SkillCreatorNodeClass: _fail("Failed to load SkillCreatorNodeClass"); return
	if not AIRequestHandlerClass: _fail("Failed to load AIRequestHandlerClass"); return
	if not PromptBuilderClass: _fail("Failed to load PromptBuilderClass"); return

	var root = Node.new()
	root.name = "TestRoot"
	
	var chat = AIChatClass.new()
	chat.name = "AIChat"
	root.add_child(chat)
	
	# We create a specific script for the test skill to implement a method
	var skill_script = GDScript.new()
	skill_script.source_code = """
@tool
extends "res://addons/ai_assistant/skills/ai_skill_node.gd"

func test_method(args: Dictionary) -> String:
	return "Test successful!"
"""
	var reload_err = skill_script.reload()
	if reload_err != OK:
		_fail("Failed to reload skill_script: %d" % reload_err); return
	
	var skill = Node.new()
	skill.set_script(skill_script)
	skill.name = "TestSkill"
	skill.set("description", "A test skill node.")
	skill.set("definition", "Full instructions for TestSkill.")
	
	var test_tools: Array[Dictionary] = [{
		"type": "function",
		"function": {
			"name": "test_method",
			"description": "A test method.",
			"parameters": {"type": "object", "properties": {}}
		}
	}]
	skill.set("tools", test_tools)
	
	if skill.get("tools").is_empty():
		# Try fallback if set() didn't work as expected
		skill.tools = test_tools
		if skill.tools.is_empty():
			_fail("Failed to set 'tools' property on TestSkill node."); return
	
	chat.add_child(skill)
	
	# 1. Test Discovery
	print("\n[TEST 1] Skill Discovery")
	var discovered = chat._discover_active_skills()
	if discovered.size() != 1:
		_fail("Expected 1 discovered skill, got %d" % discovered.size()); return
	if discovered[0].name != "TestSkill":
		_fail("Wrong skill name discovered: " + discovered[0].name); return
	print("SUCCESS: Discovery verified.")

	# 2. Test Discovery Context
	print("\n[TEST 2] Discovery Context")
	var context = PromptBuilderClass.get_skills_discovery_context(discovered)
	if not "AVAILABLE SKILLS:" in context:
		_fail("Discovery context missing header."); return
	if not "TestSkill: A test skill node." in context:
		_fail("Discovery context missing TestSkill description."); return
	print("SUCCESS: Discovery context verified.")

	# 3. Test Activation
	print("\n[TEST 3] Activation")
	var handler = AIRequestHandlerClass.new(chat)
	var activation_result = await handler.activate_skill("TestSkill")
	if not "Full instructions for TestSkill." in activation_result:
		_fail("Activation result missing definition."); return
	if not handler._dynamic_tool_targets.has("test_method"):
		_fail("test_method not registered in dynamic tool targets."); return
	print("SUCCESS: Activation verified.")

	# 4. Test Tool Execution (Routing)
	print("\n[TEST 4] Tool Execution Routing")
	var tool_call = {
		"function": {
			"name": "test_method",
			"arguments": "{}"
		}
	}
	var execution_result = await handler._execute_tool(tool_call)
	if execution_result != "Test successful!":
		_fail("Tool execution routing failed: " + str(execution_result)); return
	print("SUCCESS: Tool execution routing verified.")

	# 4b. Test Registration Loop in execute()
	print("[4b] Tool Registration Loop in execute()")
	var mock_client = MockAIClient.new()
	mock_client.response_queue = ["Hello!"]
	handler.mock_client = mock_client
	
	# This call triggers the loop that builds all_tools
	var messages: Array[Dictionary] = [{"role": "user", "content": "Hi"}]
	await handler.execute(messages)
	
	var passed_tools = mock_client.last_request_params.get("tools", [])
	var has_test_method = false
	for t in passed_tools:
		if t.get("function", {}).get("name") == "test_method":
			has_test_method = true
			break
	
	if not has_test_method:
		_fail("test_method not found in tools passed to AIClient."); return
	print("SUCCESS: Tool registration loop verified.")

	# 5. Test SkillCreatorNode (Script-First Workflow)
	print("\n[TEST 5] SkillCreatorNode")
	var creator = SkillCreatorNodeClass.new()
	creator.name = "SkillCreator"
	chat.add_child(creator)
	
	var activation_creator = await handler.activate_skill("SkillCreator")
	if not handler._dynamic_tool_targets.has("create_skill_node"):
		_fail("create_skill_node not registered after activating SkillCreator."); return
		
	# 5a. Create the script file first
	print("[5a] Create script file")
	var script_path = "res://ai_skills/scripts/test_generated_skill.gd"
	var script_content = """
@tool
extends "res://addons/ai_assistant/skills/ai_skill_node.gd"
func _init():
	description = "Generated description"
	definition = "Generated instructions"
	tools = [{"type": "function", "function": {"name": "generated_tool", "parameters": {"type": "object", "properties": {}}}}]
func generated_tool(args: Dictionary) -> String:
	return "Generated tool success!"
"""
	var dir = script_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file = FileAccess.open(script_path, FileAccess.WRITE)
	file.store_string(script_content)
	file.close()
	print("SUCCESS: Script file created.")

	# 5b. Instantiate the node
	print("[5b] Instantiate node via tool")
	var create_call = {
		"function": {
			"name": "create_skill_node",
			"arguments": JSON.stringify({
				"name": "GeneratedSkill",
				"script_path": script_path
			})
		}
	}
	var create_result = await handler._execute_tool(create_call)
	if not "Successfully created" in create_result:
		_fail("create_skill_node execution failed: " + create_result); return
		
	var gen_node = chat.get_node_or_null("GeneratedSkill")
	if not gen_node:
		_fail("GeneratedSkill node not found."); return
	
	# Test if we can activate and call the new skill's tool
	await handler.activate_skill("GeneratedSkill")
	var action_call = {
		"function": {
			"name": "generated_tool",
			"arguments": "{}"
		}
	}
	var action_result = await handler._execute_tool(action_call)
	if action_result != "Generated tool success!":
		_fail("Failed to call tool on generated skill: " + action_result); return
		
	print("SUCCESS: SkillCreatorNode verified with script-first workflow.")

	print("\nALL TESTS PASSED!")
	root.free()
	quit(0)

func _fail(msg: String):
	print("FAILED: ", msg)
	quit(1)
