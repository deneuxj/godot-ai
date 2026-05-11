## Test script for ExecuteScriptTool.
##
## This script tests the ExecuteScriptTool by simulating AI tool calls.

extends Node

const ExecuteScriptTool = preload("res://addons/ai_assistant/tools/execute_script_tool.gd")
const CustomLogger = preload("res://addons/ai_assistant/generator/custom_logger.gd")
const ScriptExecutor = preload("res://addons/ai_assistant/generator/script_executor.gd")

func _ready() -> void:
	print("--- Starting ExecuteScriptTool Test ---")
	
	# Setup Logger for testing
	var logger = CustomLogger.new()
	OS.add_logger(logger)
	ScriptExecutor.register_logger(logger)
	
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

	# Test 4: Error handling - Script with runtime error
	print("\n--- Test 4: Error handling (Runtime error) ---")
	var runtime_error_script = """
static func execute(node: Node):
	var obj = null
	obj.some_method() # This will crash (null reference)
"""
	args = {
		"script_content": runtime_error_script
	}
	result = tool.execute(args)
	print("Result: ", result)
	if "Error" in result or "encounter" in result:
		print("SUCCESS: Runtime error correctly reported.")
	else:
		print("FAILURE: Runtime error NOT reported. It was reported as: ", result)

	# Test 5: Return value reporting
	print("\n--- Test 5: Return value reporting ---")
	var return_val_script = """
static func execute(node: Node):
	return "Calculated Value: 123"
"""
	args = {
		"script_content": return_val_script
	}
	result = tool.execute(args)
	print("Result: ", result)
	if "Return value: Calculated Value: 123" in result:
		print("SUCCESS: Return value correctly reported.")
	else:
		print("FAILURE: Return value NOT reported correctly.")

	print("\n--- ExecuteScriptTool Test Complete ---")
	get_tree().quit()
