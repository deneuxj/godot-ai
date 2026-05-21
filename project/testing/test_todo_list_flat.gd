## Test for ManageTodoListTool (Flat List) using MockAIClient.

extends SceneTree

const AIChat = preload("res://addons/ai_assistant/ai_chat.gd")
const MockAIClient = preload("res://addons/ai_assistant/ai_client/mock_ai_client.gd")

var chat: AIChat
var mock: MockAIClient

func _init() -> void:
	_run_everything()

func _run_everything() -> void:
	print("--- Starting TODO LIST (Flat) Mock Test ---")
	
	chat = AIChat.new()
	chat.enable_todo_list = true
	root.add_child(chat)
	
	mock = MockAIClient.new()
	chat.mock_client = mock
	
	await _run_tests()
	
	print("\n--- TODO LIST (Flat) Mock Test Complete ---")
	quit()


func _run_tests() -> void:
	# 1. Test 'add'
	print("\nTesting 'add' operation...")
	await _test_todo_op({
		"operation": "add",
		"task": "First task"
	})
	_verify_todo(1, "First task", false)

	# 2. Test 'add' another
	print("\nTesting another 'add'...")
	await _test_todo_op({
		"operation": "add",
		"task": "Second task"
	})
	_verify_todo(2, "Second task", false)

	# 3. Test 'update' (mark done)
	print("\nTesting 'update' (mark done)...")
	await _test_todo_op({
		"operation": "update",
		"index": 0,
		"done": true
	})
	_verify_todo(2, "First task", true, 0)

	# 4. Test 'update' (change text)
	print("\nTesting 'update' (change text)...")
	await _test_todo_op({
		"operation": "update",
		"index": 1,
		"task": "Modified task"
	})
	_verify_todo(2, "Modified task", false, 1)

	# 5. Test 'remove'
	print("\nTesting 'remove'...")
	await _test_todo_op({
		"operation": "remove",
		"index": 0
	})
	_verify_todo(1, "Modified task", false, 0)

	# 6. Test 'clear'
	print("\nTesting 'clear'...")
	await _test_todo_op({
		"operation": "clear"
	})
	if chat.todo_list.is_empty():
		print("SUCCESS: List is empty.")
	else:
		print("FAILURE: List is NOT empty: ", chat.todo_list)


func _test_todo_op(args: Dictionary) -> void:
	mock.response_queue.append({
		"tool_calls": [
			{
				"id": "call_todo",
				"type": "function",
				"function": {
					"name": "manage_todo_list",
					"arguments": JSON.stringify(args)
				}
			}
		]
	})
	mock.response_queue.append("I have updated the TODO list.")
	
	chat.send_message("Do a TODO operation.")
	await chat.chat_finished


func _verify_todo(expected_size: int, expected_text: String = "", expected_done: bool = false, index: int = -1) -> void:
	var list = chat.todo_list
	if list.size() != expected_size:
		print("FAILURE: Size mismatch. Expected %d, got %d" % [expected_size, list.size()])
		return
	
	if index == -1:
		index = list.size() - 1
		
	if expected_size > 0:
		var task = list[index]
		if task.text != expected_text:
			print("FAILURE: Text mismatch at index %d. Expected '%s', got '%s'" % [index, expected_text, task.text])
		elif task.done != expected_done:
			print("FAILURE: Done mismatch at index %d. Expected %s, got %s" % [index, expected_done, task.done])
		else:
			print("SUCCESS: Task at index %d matches: %s (done: %s)" % [index, task.text, task.done])
	else:
		print("SUCCESS: List size is 0 as expected.")
