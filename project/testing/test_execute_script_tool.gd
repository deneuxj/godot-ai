## Test script for ExecuteScriptTool.
##
## This script tests the ExecuteScriptTool by simulating AI tool calls.

extends Node

const ExecuteScriptTool = preload("res://addons/ai_assistant/tools/execute_script_tool.gd")

func _ready() -> void:
	print("--- Starting ExecuteScriptTool Test ---")
	
	var tool = ExecuteScriptTool.new()
	tool.context_node = self # Set this node as the context
	
	# Test 1: Successful execution
	print("\n--- Test 1: Successful execution (static func execute(node)) ---")
	var script_content = """
static func execute(node: Node):
	var sprite = Sprite3D.new()
	sprite.name = "GeneratedSprite1"
	node.add_child(sprite)
"""
	var args = {
		"script_content": script_content
	}
	
	var result = tool.execute(args)
	print("Result: ", result)
	
	var generated_node = get_node_or_null("GeneratedSprite1")
	if generated_node:
		print("SUCCESS: GeneratedSprite1 found in tree.")
		generated_node.free()
	else:
		print("FAILURE: GeneratedSprite1 NOT found in tree.")

	# Test 2: Error handling - Script without execute() function
	print("\n--- Test 2: Error handling (Missing execute() function) ---")
	var invalid_script = """
static func some_other_function(node):
	pass
"""
	args = {
		"script_content": invalid_script
	}
	result = tool.execute(args)
	print("Result: ", result)
	if "Error" in result:
		print("SUCCESS: Error correctly reported.")
	else:
		print("FAILURE: Error NOT reported for missing execute() function.")

	# Test 3: Error handling - Script with compilation error
	print("\n--- Test 3: Error handling (Compilation error) ---")
	var compilation_error_script = """
static func execute(node):
	invalid_syntax here
"""
	args = {
		"script_content": compilation_error_script
	}
	result = tool.execute(args)
	print("Result: ", result)
	if "Error" in result:
		print("SUCCESS: Error correctly reported.")
	else:
		print("FAILURE: Error NOT reported for compilation error.")

	print("\n--- ExecuteScriptTool Test Complete ---")
	get_tree().quit()
