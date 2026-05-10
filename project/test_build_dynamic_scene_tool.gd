## Test script for BuildDynamicSceneTool.
##
## This script tests the BuildDynamicSceneTool by simulating AI tool calls.
## It covers:
## 1. Successful node creation and adding to the tree.
## 2. Error handling (invalid script).

extends Node

const BuildDynamicSceneTool = preload("res://addons/ai_assistant/tools/build_dynamic_scene_tool.gd")

func _ready() -> void:
	print("--- Starting BuildDynamicSceneTool Test ---")
	
	var tool = BuildDynamicSceneTool.new()
	tool.context_node = self # Set this node as the context
	
	# Test 1: Successful node creation and adding to tree
	print("\n--- Test 1: Successful node creation (add_to_tree=true) ---")
	var script_content = """
extends Node
func build() -> Node:
	var sprite = Sprite3D.new()
	sprite.name = "GeneratedSprite1"
	return sprite
"""
	var args = {
		"script_content": script_content,
		"add_to_tree": true
	}
	
	var result = tool.execute(args)
	print("Result: ", result)
	
	var generated_node = get_node_or_null("GeneratedSprite1")
	if generated_node:
		print("SUCCESS: GeneratedSprite1 found in tree.")
		generated_node.free()
	else:
		print("FAILURE: GeneratedSprite1 NOT found in tree.")

	# Test 1b: Successful node creation (add_to_tree=false)
	print("\n--- Test 1b: Successful node creation (add_to_tree=false) ---")
	script_content = """
extends Node
func build() -> Node:
	var sprite = Sprite3D.new()
	sprite.name = "GeneratedSprite2"
	return sprite
"""
	args = {
		"script_content": script_content,
		"add_to_tree": false
	}
	
	result = tool.execute(args)
	print("Result: ", result)
	
	var generated_node2 = get_node_or_null("GeneratedSprite2")
	if generated_node2:
		print("FAILURE: GeneratedSprite2 found in tree but add_to_tree was false.")
		generated_node2.free()
	else:
		print("SUCCESS: GeneratedSprite2 NOT found in tree.")
	
	# Test 2: Error handling - Script without build() function
	print("\n--- Test 2: Error handling (Missing build() function) ---")
	var invalid_script = """
extends Node
func some_other_function():
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
		print("FAILURE: Error NOT reported for missing build() function.")

	# Test 3: Error handling - Script with compilation error
	print("\n--- Test 3: Error handling (Compilation error) ---")
	var compilation_error_script = """
extends Node
func build() -> Node:
	invalid_syntax here
	return null
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

	# Test 4: Save as scene (Expect error if not in editor)
	print("\n--- Test 4: Save as scene (add_to_tree=false, save_as_scene=true) ---")
	args = {
		"script_content": script_content,
		"add_to_tree": false,
		"save_as_scene": true,
		"scene_path": "res://generated/test_saved_scene.tscn"
	}
	result = tool.execute(args)
	print("Result: ", result)
	if Engine.is_editor_hint():
		if "Node saved as scene" in result:
			print("SUCCESS: Scene saved (Editor mode).")
		else:
			print("FAILURE: Scene not saved in Editor mode.")
	else:
		if "Error: save_as_scene is only available in the Godot Editor" in result:
			print("SUCCESS: Correct error reported when not in Editor.")
		else:
			print("FAILURE: Unexpected result for save_as_scene outside of Editor.")

	print("\n--- BuildDynamicSceneTool Test Complete ---")
	get_tree().quit()
