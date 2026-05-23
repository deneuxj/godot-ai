@tool
extends Node2D

## Regression Test for LLM Skill Creation
## Tests the autonomous creation, activation, and usage of a new skill.

const AIChat = preload("res://addons/ai_assistant/ai_chat.gd")
const SkillCreatorNode = preload("res://addons/ai_assistant/skills/skill_creator_node.gd")

@export var api_endpoint: String = "http://127.0.0.1:1234"
@export var models_to_test: Array[String] = [
	"qwen/qwen3-coder-30b",
	"qwen/qwen3.6-35b-a3b",
	"qwen/qwen3.5-9b",
	"google/gemma-4-26b-a4b"
]

@onready var _log_text: RichTextLabel = $UI/VBox/Log
@onready var _run_button: Button = $UI/VBox/Controls/RunBtn
@onready var _endpoint_edit: LineEdit = $UI/VBox/Controls/Endpoint

var _chat: AIChat

func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	if _endpoint_edit:
		_endpoint_edit.text = api_endpoint
	if _run_button:
		_run_button.pressed.connect(_run_all_tests)
	
	# Setup AIChat
	_chat = AIChat.new()
	_chat.name = "TestAIChat"
	add_child(_chat)
	
	# Enable resource modification for skill creation
	_chat.enable_modify_resources = true
	_chat.enable_execute_script = false
	_chat.enable_project_resources = true
	_chat.enable_godot_docs = false
	_chat.enable_capture_view = false
	_chat.enable_node_hierarchy = false
	_chat.enable_todo_list = false
	
	# Inject the Skill Creator
	var creator = SkillCreatorNode.new()
	creator.name = "SkillCreator"
	_chat.add_child(creator)
	
	_log("Ready to run skill creation regression tests.")
	
	# Auto-run if headless
	if DisplayServer.get_name() == "headless":
		_log("Headless mode detected. Auto-starting tests...", "yellow")
		await get_tree().create_timer(1.0).timeout
		await _run_all_tests()
		get_tree().quit()


func _log(msg: String, color: String = "white") -> void:
	print(msg)
	if _log_text:
		_log_text.append_text("[color=%s]%s[/color]\n" % [color, msg])


func _run_all_tests() -> void:
	if _run_button:
		_run_button.disabled = true
	if _log_text:
		_log_text.clear()
	_log("Starting skill creation regression tests for %d models..." % models_to_test.size(), "yellow")
	
	if _endpoint_edit:
		api_endpoint = _endpoint_edit.text.strip_edges()
	_chat.api_endpoint = api_endpoint
	
	for model_name in models_to_test:
		await _run_test_for_model(model_name)
		_log("-----------------------------------------", "gray")
	
	_log("All tests completed.", "yellow")
	_run_button.disabled = false


func _run_test_for_model(model_name: String) -> void:
	_log("Testing Model: [b]%s[/b]" % model_name, "cyan")
	
	_chat.model = model_name
	_chat.clear_history()
	
	# 1. Load Model
	_log("Loading model in LM Studio...", "gray")
	var AIRequestHandler = load("res://addons/ai_assistant/ai_client/ai_request_handler.gd")
	var temp_handler = AIRequestHandler.new(_chat, api_endpoint)
	var err = await temp_handler.load_model(model_name)
	if err != OK:
		_log("FAILED: Could not load model '%s' in LM Studio. Error: %d" % [model_name, err], "red")
		return
	
	var prompt = """Please perform the following steps:
1. Use 'activate_skill' to activate 'SkillCreator'.
2. Create a new skill script at 'res://ai_skills/scripts/square_root_skill.gd' using 'modify_project_resource'. 
   The script should define a tool 'compute_sqrt' that takes a 'number' (float) and returns its square root.
   Ensure the script follows the AISkillNode template (metadata in _init).
3. Instantiate the skill node as 'SquareRootSkill' using 'create_skill_node'.
4. Activate 'SquareRootSkill'.
5. Use 'compute_sqrt' to calculate the square root of 144.
Output ONLY the tool calls and the final answer."""

	_log("Prompt: [i]%s[/i]" % prompt, "gray")
	_chat.send_message(prompt)
	
	# Wait for completion or error
	var result = await _wait_for_chat()
	
	if result.is_empty():
		_log("FAILED: No response received or timeout.", "red")
		await _cleanup_and_unload(model_name)
		return

	# Validation
	var creator_activated = false
	var script_created = false
	var node_instantiated = false
	var skill_activated = false
	var tool_used = false
	var correct_result = false
	
	for msg in _chat.chat_history:
		_log("  - Msg Role: %s | Content: %s" % [msg.role, str(msg.get("content", "")).left(50) + "..."], "gray")
		if msg.has("tool_calls"):
			for call in msg["tool_calls"]:
				var fn = call.function.name
				var args = JSON.parse_string(call.function.arguments)
				_log("    - Tool Call: %s" % fn, "gray")
				
				if fn == "activate_skill":
					if args.get("name") == "SkillCreator":
						creator_activated = true
					elif args.get("name") == "SquareRootSkill":
						skill_activated = true
				elif fn == "modify_project_resource":
					if args.get("path") == "res://ai_skills/scripts/square_root_skill.gd":
						script_created = true
				elif fn == "create_skill_node":
					if args.get("name") == "SquareRootSkill":
						node_instantiated = true
				elif fn == "compute_sqrt":
					tool_used = true
		
		if msg.role == "tool" and msg.name == "compute_sqrt":
			var content = str(msg.content).strip_edges()
			_log("    - Tool Result: %s" % content, "gray")
			if content.to_float() == 12.0:
				correct_result = true
	
	if creator_activated and script_created and node_instantiated and skill_activated and tool_used and correct_result:
		_log("SUCCESS: Model correctly handled the entire skill creation pipeline.", "green")
	else:
		_log("FAILED: Pipeline incomplete.", "red")
		if not creator_activated: _log("  - SkillCreator was NOT activated.", "orange")
		if not script_created: _log("  - Script was NOT created.", "orange")
		if not node_instantiated: _log("  - Node was NOT instantiated.", "orange")
		if not skill_activated: _log("  - SquareRootSkill was NOT activated.", "orange")
		if not tool_used: _log("  - Tool 'compute_sqrt' was NOT used.", "orange")
		if not correct_result: _log("  - Result was incorrect or missing.", "orange")
	
	await _cleanup_and_unload(model_name)


func _cleanup_and_unload(model_name: String) -> void:
	_log("Cleaning up...", "gray")
	# Delete generated script
	var script_path = "res://ai_skills/scripts/square_root_skill.gd"
	if FileAccess.file_exists(script_path):
		var dir = DirAccess.open("res://ai_skills/scripts/")
		dir.remove("square_root_skill.gd")
		if FileAccess.file_exists(script_path + ".uid"):
			dir.remove("square_root_skill.gd.uid")
	
	# Remove node
	if _chat.has_node("SquareRootSkill"):
		_chat.get_node("SquareRootSkill").queue_free()
	
	# Unload model
	var AIRequestHandler = load("res://addons/ai_assistant/ai_client/ai_request_handler.gd")
	var temp_handler = AIRequestHandler.new(_chat, api_endpoint)
	await temp_handler.unload_model(model_name)


func _wait_for_chat() -> String:
	var timeout = 120.0 # Longer timeout for complex multi-step task
	var time_passed = 0.0
	
	while _chat.chat_status == AIChat.ChatStatus.BUSY:
		await get_tree().create_timer(1.0).timeout
		time_passed += 1.0
		if time_passed >= timeout:
			_chat.cancel()
			return ""
	
	return "done"
