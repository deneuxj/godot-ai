@tool
extends AITool

## Manage flat TODO list for the AI agent.
## Allows adding, removing, and updating TODO tasks persisted in the AI node.

func _init() -> void:
	name = "manage_todo_list"
	description = "Manage a flat list of TODO tasks. Use 'add' to append a task, 'remove' to delete a task by index, 'update' to mark a task as done/undone or change its text, 'list' to see all tasks, and 'clear' to wipe the list."


func get_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"operation": {
				"type": "string",
				"enum": ["add", "remove", "update", "list", "clear"],
				"description": "The operation to perform."
			},
			"task": {
				"type": "string",
				"description": "The text of the task (required for 'add', optional for 'update')."
			},
			"index": {
				"type": "integer",
				"description": "The 0-based index of the task (required for 'remove' and 'update')."
			},
			"done": {
				"type": "boolean",
				"description": "The completion status of the task (optional for 'update')."
			}
		},
		"required": ["operation"]
	}


func execute(args: Dictionary) -> Variant:
	if not context_node or not "todo_list" in context_node:
		return JSON.stringify({"error": "Tool context node does not support TODO list."})

	var operation: String = args.get("operation", "")
	var list: Array = context_node.todo_list.duplicate(true)
	
	var result: Variant = null
	match operation:
		"add":
			var task_text: String = args.get("task", "")
			if task_text.is_empty():
				result = {"error": "Task text is required for 'add' operation."}
			else:
				list.append({"text": task_text, "done": false})
				context_node.todo_list = list
				result = {"success": true, "message": "Task added: %s" % task_text, "index": list.size() - 1}

		"remove":
			if not "index" in args:
				result = {"error": "Index is required for 'remove' operation."}
			else:
				var index: int = args.get("index")
				if index >= 0 and index < list.size():
					var removed = list.pop_at(index)
					context_node.todo_list = list
					result = {"success": true, "message": "Task removed: %s" % removed.text}
				else:
					result = {"error": "Invalid task index: %d. The list has %d tasks." % [index, list.size()]}

		"update":
			if not "index" in args:
				result = {"error": "Index is required for 'update' operation."}
			else:
				var index: int = args.get("index")
				if index >= 0 and index < list.size():
					var task = list[index]
					if "task" in args:
						task["text"] = args.get("task")
					if "done" in args:
						task["done"] = args.get("done")
					
					context_node.todo_list = list
					result = {"success": true, "message": "Task at index %d updated." % index, "task": task}
				else:
					result = {"error": "Invalid task index: %d. The list has %d tasks." % [index, list.size()]}

		"list":
			result = {"todo_list": list}

		"clear":
			list.clear()
			context_node.todo_list = list
			result = {"success": true, "message": "TODO list cleared."}

		_:
			result = {"error": "Unknown operation: %s" % operation}

	return JSON.stringify(result)
