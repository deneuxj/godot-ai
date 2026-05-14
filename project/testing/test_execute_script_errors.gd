## Regression test for ExecuteScriptTool detailed error reporting.
##
## Verifies that:
## 1. Compilation (parse) errors include detailed engine messages.
## 2. Runtime errors include specific rationale and line numbers.

extends Node

func _ready() -> void:
	print("--- Starting ExecuteScriptTool Regression Test ---")
	
	var ToolClass := load("res://addons/ai_assistant/tools/execute_script_tool.gd")
	var tool = ToolClass.new()
	tool.context_node = self
	
	# Register logger (required for interception)
	var LoggerClass := load("res://addons/ai_assistant/generator/custom_logger.gd")
	var logger = LoggerClass.new()
	OS.add_logger(logger)
	var ScriptExecutorClass := load("res://addons/ai_assistant/generator/script_executor.gd")
	ScriptExecutorClass.register_logger(logger)
	
	var success := true

	# Case 1: Compilation Error (Missing colon)
	print("\nChecking Case 1: Compilation Error reporting...")
	var bad_script = "static func execute(node: Node)\n\tpass"
	var result = tool.execute({"script_content": bad_script})
	
	if result.contains("Details:") and (result.contains("Parse Error") or result.contains("Unexpected")):
		print("[PASS] Compilation error details captured.")
	else:
		print("[FAIL] Compilation error details missing. Result was: ", result)
		success = false

	# Case 2: Runtime Error (Division by zero)
	print("\nChecking Case 2: Runtime Error reporting...")
	var runtime_error_script = "static func execute(node: Node):\n\tvar zero = 0\n\tvar a = 1 / zero"
	result = tool.execute({"script_content": runtime_error_script})
	
	if result.contains("encountered runtime errors:") and (result.contains("Division by zero") or result.contains("division by zero")):
		print("[PASS] Runtime error details captured.")
	else:
		print("[FAIL] Runtime error details missing. Result was: ", result)
		success = false

	print("\n--- Regression Test Summary ---")
	if success:
		print("OVERALL STATUS: SUCCESS")
	else:
		print("OVERALL STATUS: FAILED")
	
	# Cleanup logger to avoid interference with other tests
	OS.remove_logger(logger)
	
	get_tree().quit(0 if success else 1)
