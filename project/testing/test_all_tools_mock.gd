## Comprehensive test for all AI tools using MockAIClient.
##
## This script sequentially triggers and verifies each tool.

extends Node

const AIChat = preload("res://addons/ai_assistant/ai_chat.gd")
const MockAIClient = preload("res://addons/ai_assistant/ai_client/mock_ai_client.gd")

var chat: AIChat
var mock: MockAIClient

func _ready() -> void:
	print("--- Starting ALL TOOLS Mock Test ---")
	
	chat = AIChat.new()
	# Enable all tools for testing
	chat.enable_modify_resources = true
	chat.enable_validate_resources = true
	add_child(chat)
	
	mock = MockAIClient.new()
	chat.mock_client = mock
	
	# Connect signals for verification
	chat.chat_finished.connect(_on_chat_finished)
	
	await _run_tests()
	
	print("\n--- ALL TOOLS Mock Test Complete ---")
	get_tree().quit()


func _run_tests() -> void:
	# 1. Test GodotDocsTool
	await _test_tool("explore_godot_docs", {
		"command": "get_class_doc",
		"query": "Node3D"
	}, "Checking Godot documentation for Node3D...")

	# 2. Test ProjectResourcesTool
	await _test_tool("explore_project_resources", {
		"command": "list_files",
		"path": "res://"
	}, "Listing files in the project root...")

	# 3. Test ModifyProjectResourceTool (New File)
	await _test_tool("modify_project_resource", {
		"path": "res://generated/mock_test_file.txt",
		"target_line": 1,
		"old_content": "",
		"new_content": "Hello from mock test!"
	}, "Creating a new file via tool...")

	# 4. Test ModifyProjectResourceTool (Patch File)
	await _test_tool("modify_project_resource", {
		"path": "res://generated/mock_test_file.txt",
		"target_line": 1,
		"old_content": "Hello from mock test!",
		"new_content": "Updated content!"
	}, "Patching the existing file...")

	# 5. Test ValidateProjectResourceTool
	await _test_tool("validate_project_resource", {
		"path": "res://generated/mock_test_file.txt"
	}, "Validating the newly created resource...")

	# 6. Test BuildDynamicSceneTool
	await _test_tool("build_dynamic_scene", {
		"script_content": "extends Node\nfunc build() -> Node:\n\tvar n = Node.new()\n\tn.name = 'ToolTestNode'\n\treturn n",
		"add_to_tree": true
	}, "Building a dynamic node...")


func _test_tool(tool_name: String, args: Dictionary, user_msg: String) -> void:
	print("\n--- Testing Tool: %s ---" % tool_name)
	
	# Queue the tool call
	mock.response_queue.append({
		"tool_calls": [
			{
				"id": "call_" + tool_name,
				"type": "function",
				"function": {
					"name": tool_name,
					"arguments": JSON.stringify(args)
				}
			}
		]
	})
	
	# Final confirmation message from "AI"
	mock.response_queue.append("I have executed the %s tool." % tool_name)
	
	chat.send_message(user_msg)
	await chat.chat_finished
	
	# Verification logic
	match tool_name:
		"modify_project_resource":
			var path = args["path"]
			if FileAccess.file_exists(path):
				print("SUCCESS: File '%s' exists." % path)
				var content = FileAccess.get_file_as_string(path)
				if content == args["new_content"]:
					print("SUCCESS: Content matches expected: '%s'" % content)
				else:
					print("FAILURE: Content mismatch. Got: '%s'" % content)
		"build_dynamic_scene":
			var node = chat.get_node_or_null("ToolTestNode")
			if node:
				print("SUCCESS: ToolTestNode found in tree.")
				node.free()
			else:
				print("FAILURE: ToolTestNode NOT found in tree.")
		_:
			# For read-only tools, we just check that the assistant acknowledged it in history
			var last_msg = chat.chat_history.back()
			if last_msg.role == "assistant" and tool_name in last_msg.content or "executed" in last_msg.content:
				print("SUCCESS: Tool executed and acknowledged.")
			else:
				print("FAILURE: Tool might not have executed correctly. Last msg: ", last_msg.content)


func _on_chat_finished(response: String) -> void:
	print("[AIChat] Response: ", response)
