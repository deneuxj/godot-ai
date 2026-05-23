@tool
extends Node2D

## Regression Test for LLM Skill Compatibility
## Tests discovery, activation, and usage of skills through the real AIChat stack.

const AIChat = preload("res://addons/ai_assistant/ai_chat.gd")
const DummyMathSkill = preload("res://testing/dummy_math_skill.gd")

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
	
	# Restrict tools to prevent accidental project modification
	_chat.enable_modify_resources = false
	_chat.enable_execute_script = false
	_chat.enable_project_resources = true
	_chat.enable_godot_docs = false
	_chat.enable_capture_view = false
	_chat.enable_node_hierarchy = false
	_chat.enable_todo_list = false
	
	# Inject the Skill
	var skill = Node.new()
	skill.set_script(DummyMathSkill)
	skill.name = "MathSkill"
	_chat.add_child(skill)
	
	_log("Ready to run regression tests.")
	
	# Auto-run if headless
	if DisplayServer.get_name() == "headless":
		_log("Headless mode detected. Auto-starting tests...", "yellow")
		await get_tree().create_timer(1.0).timeout # Give network stack a moment
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
	_log("Starting regression tests for %d models..." % models_to_test.size(), "yellow")
	
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
	
	# 1. Load Model (Automated LM Studio Management)
	_log("Loading model in LM Studio...", "gray")
	var handler = _chat.get_node("TestAIChat_RequestHandler") if _chat.has_node("TestAIChat_RequestHandler") else null
	if not handler:
		# Create a temporary handler for model management
		var AIRequestHandler = load("res://addons/ai_assistant/ai_client/ai_request_handler.gd")
		var temp_handler = AIRequestHandler.new(_chat, api_endpoint)
		var err = await temp_handler.load_model(model_name)
		if err != OK:
			_log("FAILED: Could not load model '%s' in LM Studio. Error: %d" % [model_name, err], "red")
			return
	
	var prompt = "Please use the 'activate_skill' tool to activate 'MathSkill', and then use its 'add_numbers' tool to calculate 123 + 456. Output ONLY the tool calls and final answer."
	_log("Prompt: [i]%s[/i]" % prompt, "gray")
	
	_chat.send_message(prompt)
	
	# Wait for completion or error
	var result = await _wait_for_chat()
	
	if result.is_empty():
		_log("FAILED: No response received.", "red")
		_unload_model_after_test(model_name)
		return

	# Validation
	var activated = false
	var tool_used = false
	var correct_result = false
	
	for msg in _chat.chat_history:
		_log("  - Msg Role: %s | Content: %s" % [msg.role, str(msg.get("content", "")).left(50) + "..."], "gray")
		if msg.has("tool_calls"):
			for call in msg["tool_calls"]:
				var fn = call.function.name
				_log("    - Tool Call: %s" % fn, "gray")
				if fn == "activate_skill":
					var args = JSON.parse_string(call.function.arguments)
					if args.get("name") == "MathSkill":
						activated = true
				elif fn == "add_numbers":
					tool_used = true
		
		if msg.role == "tool" and msg.name == "add_numbers":
			var content = str(msg.content).strip_edges()
			_log("    - Tool Result: %s" % content, "gray")
			if content.to_float() == 579.0:
				correct_result = true
	
	if activated and tool_used and correct_result:
		_log("SUCCESS: Model correctly handled skill discovery, activation, and usage.", "green")
	else:
		_log("FAILED: Pipeline incomplete.", "red")
		if not activated: _log("  - Skill 'MathSkill' was NOT activated.", "orange")
		if not tool_used: _log("  - Tool 'add_numbers' was NOT used.", "orange")
		if not correct_result: _log("  - Result was incorrect or missing.", "orange")
	
	# 2. Cleanup
	await _unload_model_after_test(model_name)


func _unload_model_after_test(model_name: String) -> void:
	_log("Unloading model...", "gray")
	var AIRequestHandler = load("res://addons/ai_assistant/ai_client/ai_request_handler.gd")
	var temp_handler = AIRequestHandler.new(_chat, api_endpoint)
	await temp_handler.unload_model(model_name)


func _wait_for_chat() -> String:
	var timeout = 60.0 # 60 seconds timeout per model
	var time_passed = 0.0
	
	while _chat.chat_status == AIChat.ChatStatus.BUSY:
		await get_tree().create_timer(0.5).timeout
		time_passed += 0.5
		if time_passed >= timeout:
			_chat.cancel()
			return ""
	
	if _chat.chat_history.is_empty():
		return ""
		
	var last = _chat.chat_history.back()
	if last.role == "assistant":
		return last.content
	return ""
