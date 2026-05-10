## Test script for AIChat node.
##
## Run this via "Scene > Run" or by attaching to a node in a scene.
## It tests sequential chat to verify history/context persistence.

extends Node


func _ready() -> void:
	print("--- Starting AIChat Test ---")
	
	var AIChatClass := load("res://addons/ai_assistant/ai_chat.gd")
	var chat = AIChatClass.new()
	add_child(chat)
	
	chat.chat_started.connect(func(): print("[AIChat] Request started..."))
	chat.progress.connect(func(chunks: Array[String]): 
		for chunk in chunks:
			printraw(chunk)
	)
	chat.chat_finished.connect(func(_response: String): 
		print("\n[AIChat] Request finished.")
	)
	chat.chat_error.connect(func(err: String): print("[AIChat] ERROR: ", err))
	
	# Test 1: First message
	print("\n--- Test 1: Initial Greeting ---")
	chat.send_message("Hello! My name is Johann. Remember it.")
	await chat.chat_finished
	
	# Test 2: Sequential message (Context check)
	print("\n--- Test 2: Context Check ---")
	chat.send_message("What is my name?")
	await chat.chat_finished
	
	print("\n--- Chat History ---")
	for msg in chat.chat_history:
		print("[%s]: %s" % [msg.role, msg.content])
	
	print("\n--- AIChat Test Complete ---")
	get_tree().quit()
