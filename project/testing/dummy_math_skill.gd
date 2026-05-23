@tool
extends "res://addons/ai_assistant/skills/ai_skill_node.gd"

func _init() -> void:
	description = "A specialized math skill for regression testing."
	definition = "You are a Math Expert. Use the add_numbers tool for additions. No other tools or logic allowed for math."
	tools = [
		{
			"type": "function",
			"function": {
				"name": "add_numbers",
				"description": "Adds two numbers together.",
				"parameters": {
					"type": "object",
					"properties": {
						"a": {"type": "number"},
						"b": {"type": "number"}
					},
					"required": ["a", "b"]
				}
			}
		}
	]

func add_numbers(args: Dictionary) -> String:
	var a = args.get("a", 0)
	var b = args.get("b", 0)
	return str(a + b)
