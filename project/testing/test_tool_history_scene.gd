## Comprehensive test for Tool History preservation.
extends Node

const AIChat = preload("res://addons/ai_assistant/ai_chat.gd")
const MockAIClient = preload("res://addons/ai_assistant/ai_client/mock_ai_client.gd")

func _ready() -> void:
	print("--- Starting Tool History Scene Test ---")
	
	var chat = AIChat.new()
	add_child(chat)
	
	var mock = MockAIClient.new()
	chat.mock_client = mock
	
	# 1. Prepare a tool call response
	mock.response_queue.append({
		"tool_calls": [
			{
				"id": "call_123",
				"type": "function",
				"function": {
					"name": "explore_project_resources",
					"arguments": JSON.stringify({"command": "list_files", "path": "res://"})
				}
			}
		]
	})
	
	# 2. Prepare the final text response
	mock.response_queue.append("I checked the files and found nothing.")
	
	# 3. Send message
	chat.send_message("What's in the root folder?")
	
	# 4. Wait for finish signal
	var response = await chat.chat_finished
	
	# 5. Verify History
	print("\nHistory size: ", chat.chat_history.size())
	for i in range(chat.chat_history.size()):
		var msg = chat.chat_history[i]
		var content_str = str(msg.get("content", ""))
		print("Message %d: role=%s, has_tool_calls=%s, content=%s" % [
			i, 
			msg.role, 
			msg.has("tool_calls"),
			content_str.left(50).replace("\n", " ") + "..."
		])
	
	var success = true
	if chat.chat_history.size() != 4:
		print("FAILURE: Expected 4 messages, got ", chat.chat_history.size())
		success = false
	else:
		if chat.chat_history[1].role != "assistant" or not chat.chat_history[1].has("tool_calls"):
			print("FAILURE: Message 1 should be assistant with tool_calls")
			success = false
		if chat.chat_history[2].role != "tool":
			print("FAILURE: Message 2 should be tool")
			success = false
		if chat.chat_history[3].role != "assistant" or chat.chat_history[3].get("content", "") == "":
			print("FAILURE: Message 3 should be assistant text")
			success = false
			
	if success:
		print("\nSUCCESS: Tool history preserved correctly.")
	else:
		print("\nFAILURE: Tool history missing or incorrect.")
		
	get_tree().quit()
