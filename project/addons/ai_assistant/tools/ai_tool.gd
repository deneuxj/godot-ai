## AITool - Base class for AI tools.
##
## Each tool defines its schema (for the AI) and the execution logic.

class_name AITool
extends RefCounted


## The unique name of the tool.
var name: String = ""

## Description of what the tool does.
var description: String = ""

## Optional context node (e.g., the node that triggered the AI request).
var context_node: Node = null


func _init(p_name: String, p_description: String) -> void:
	name = p_name
	description = p_description


## Returns the OpenAI-compatible tool definition dictionary.
func get_definition() -> Dictionary:
	return {
		"type": "function",
		"function": {
			"name": name,
			"description": description,
			"parameters": get_parameters()
		}
	}


## Subclasses must override this to return the parameters schema.
func get_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {},
		"required": []
	}


## Subclasses must override this to execute the tool.
## [param _arguments] is a dictionary of parsed JSON arguments from the AI.
func execute(_arguments: Dictionary) -> String:
	return "Error: execute() not implemented for tool " + name
