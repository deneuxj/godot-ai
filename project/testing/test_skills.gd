@tool
extends SceneTree

func _init():
	print("--- AI Skill System Tests ---")
	
	var SkillManagerClass = load("res://addons/ai_assistant/skills/skill_manager.gd")
	var AIRequestHandlerClass = load("res://addons/ai_assistant/ai_client/ai_request_handler.gd")
	var PromptBuilderClass = load("res://addons/ai_assistant/generator/prompt_builder.gd")
	
	# 1. Test Discovery
	print("\n[TEST 1] Skill Discovery")
	SkillManagerClass.refresh_skills()
	var all_skills = SkillManagerClass.get_all_skills()
	
	var has_creator = false
	var has_test = false
	for skill in all_skills:
		if skill.id == "skill-creator": has_creator = true
		if skill.id == "test-skill": has_test = true
	
	if not has_creator:
		_fail("skill-creator not discovered in builtin path.")
	if not has_test:
		_fail("test-skill not discovered in project path.")
	print("SUCCESS: Discovery verified.")

	# 2. Test Discovery Context (Lazy Loading)
	print("\n[TEST 2] Discovery Context (Lazy Loading)")
	var context = PromptBuilderClass.get_skills_discovery_context()
	if not "AVAILABLE SKILLS:" in context:
		_fail("Discovery context missing header.")
	if not "test-skill: Test Skill" in context:
		_fail("Discovery context missing test-skill description.")
	if "This is a specialized skill for testing" in context:
		_fail("Discovery context contains full SKILL.md body (not lazy).")
	print("SUCCESS: Discovery context verified.")

	# 3. Test Activation & Dynamic Tool Registration
	print("\n[TEST 3] Activation & Dynamic Tool Registration")
	var dummy = Node.new()
	var handler = AIRequestHandlerClass.new(dummy)
	
	if handler._active_tools.has("test_tool"):
		_fail("test_tool already registered before activation.")
		
	var activation_result = await handler.activate_skill("test-skill")
	if not "This is a specialized skill for testing" in activation_result:
		_fail("Activation result missing SKILL.md content.")
	
	if not handler._active_tools.has("test_tool"):
		_fail("test_tool not registered after activation.")
	print("SUCCESS: Activation verified.")

	# 4. Test Dynamic Tool Execution
	print("\n[TEST 4] Dynamic Tool Execution")
	var tool_call = {
		"function": {
			"name": "test_tool",
			"arguments": "{}"
		}
	}
	var execution_result = await handler._execute_tool(tool_call)
	if execution_result != "Test tool executed successfully!":
		_fail("Dynamic tool execution failed or returned wrong result: " + str(execution_result))
	print("SUCCESS: Dynamic tool execution verified.")

	# 5. Test Skill-Creator Meta-Skill
	print("\n[TEST 5] Skill-Creator Meta-Skill")
	await handler.activate_skill("skill-creator")
	if not handler._active_tools.has("create_skill_resource"):
		_fail("create_skill_resource not registered after activating skill-creator.")
		
	var create_call = {
		"function": {
			"name": "create_skill_resource",
			"arguments": JSON.stringify({
				"name": "generated-skill",
				"instructions": "# Generated Skill\nThis was created by the skill-creator."
			})
		}
	}
	var create_result = await handler._execute_tool(create_call)
	if not "Successfully created" in create_result:
		_fail("create_skill_resource execution failed: " + str(create_result))
		
	# Verify discovery of the generated skill
	var gen_skill = SkillManagerClass.get_skill("generated-skill")
	if not gen_skill:
		_fail("Generated skill not discovered by SkillManager.")
	if gen_skill.description != "Generated Skill":
		_fail("Generated skill has wrong description: " + gen_skill.description)
	print("SUCCESS: Skill-creator verified.")

	print("\nALL TESTS PASSED!")
	
	# Cleanup
	_cleanup()
	dummy.free()
	quit(0)

func _fail(msg: String):
	print("FAILED: ", msg)
	_cleanup()
	quit(1)

func _cleanup():
	# Remove test skills
	var da = DirAccess.open("res://ai_skills")
	if da:
		_rm_recursive("res://ai_skills/test-skill")
		_rm_recursive("res://ai_skills/generated-skill")

func _rm_recursive(path: String):
	var da = DirAccess.open(path)
	if not da: return
	
	da.list_dir_begin()
	var file_name = da.get_next()
	while file_name != "":
		if da.current_is_dir():
			_rm_recursive(path.path_join(file_name))
		else:
			da.remove(file_name)
		file_name = da.get_next()
	DirAccess.remove_absolute(path)
