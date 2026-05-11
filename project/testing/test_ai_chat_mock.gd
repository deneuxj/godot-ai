## Test script for AIChat using MockAIClient.
##
## This tests the chat flow and tool calling without an internet connection.

extends Node

const AIChat = preload("res://addons/ai_assistant/ai_chat.gd")
const MockAIClient = preload("res://addons/ai_assistant/ai_client/mock_ai_client.gd")

func _ready() -> void:
	print("--- Starting AIChat Mock Test ---")
	
	var chat = AIChat.new()
	add_child(chat)
	
	var mock = MockAIClient.new()
	chat.mock_client = mock
	
	chat.progress.connect(func(chunks: Array[String]): 
		for chunk in chunks:
			printraw(chunk)
	)
	chat.chat_finished.connect(func(_response: String): 
		print("\n[AIChat] Request finished.")
	)
	
	# --- Test 1: Simple Text Response ---
	print("\n--- Test 1: Simple Text Response ---")
	mock.response_queue.append("Hello! I am a mock AI. How can I help you today?")
	chat.send_message("Hi there!")
	await chat.chat_finished
	
	# --- Test 2: Tool Call Simulation ---
	print("\n--- Test 2: Tool Call Simulation (execute_script) ---")
	
	# The first response from AI is a tool call
	var tool_call = {
		"tool_calls": [
			{
				"id": "call_123",
				"type": "function",
				"function": {
					"name": "execute_script",
					"arguments": JSON.stringify({
						"script_content": "static func execute(node: Node):\n\tvar n = Node3D.new()\n\tn.name = 'MockNode'\n\tnode.add_child(n)"
					})
				}
			}
		]
	}
	mock.response_queue.append(tool_call)
	
	# The second response (after tool execution) is the final text
	mock.response_queue.append("I have successfully executed the script for you.")
	
	chat.send_message("Please execute a simple script to add a node.")
	await chat.chat_finished
	
	var mock_node = chat.get_node_or_null("MockNode")
	if mock_node:
		print("SUCCESS: MockNode found in tree.")
		mock_node.free()
	else:
		print("FAILURE: MockNode NOT found in tree.")

	print("\n--- Chat History ---")
	for msg in chat.chat_history:
		print("[%s]: %s" % [msg.role, msg.content])

	print("\n--- AIChat Mock Test Complete ---")
	get_tree().quit()
