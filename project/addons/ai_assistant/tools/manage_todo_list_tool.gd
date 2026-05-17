@tool
extends AITool

## Manage hierarchical TODO stacks for the AI agent.
## Allows pushing, popping, and updating TODO lists persisted in the AI node.

func _init() -> void:
	name = "manage_todo_list"
	description = "Manage a hierarchical stack of TODO lists. Use 'push' to start a sub-task with its own TODOs, 'pop' when that sub-task is done, and 'update' to manage the current list."


func get_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"operation": {
				"type": "string",
				"enum": ["push", "pop", "update", "list", "cancel_stack"],
				"description": "The operation to perform."
			},
			"title": {
				"type": "string",
				"description": "The title of the TODO list (required for 'push')."
			},
			"tasks": {
				"type": "array",
				"items": { "type": "string" },
				"description": "Initial tasks for the 'push' operation."
			},
			"add_tasks": {
				"type": "array",
				"items": { "type": "string" },
				"description": "New tasks to add for the 'update' operation."
			},
			"mark_done": {
				"type": "array",
				"items": { "type": "integer" },
				"description": "Indices of tasks to mark as done (0-based) for the 'update' operation."
			},
			"mark_undone": {
				"type": "array",
				"items": { "type": "integer" },
				"description": "Indices of tasks to mark as undone (0-based) for the 'update' operation."
			}
		},
		"required": ["operation"]
	}


func execute(args: Dictionary) -> Variant:
	if not context_node or not "todo_stack" in context_node:
		return JSON.stringify({"error": "Tool context node does not support TODO stack."})

	var operation: String = args.get("operation", "")
	var stack: Array = context_node.todo_stack.duplicate(true)

	var result: Variant = null
	match operation:
		"push":
			var title: String = args.get("title", "")
			if title.is_empty():
				result = {"error": "Title is required for 'push' operation."}
			else:
				var tasks: Array[Dictionary] = []
				for task_text in args.get("tasks", []):
					tasks.append({"text": task_text, "done": false})
				var new_list: Dictionary = {"title": title, "tasks": tasks}
				stack.append(new_list)
				context_node.todo_stack = stack
				result = {"success": true, "message": "TODO list '%s' pushed onto stack." % title, "current_stack_depth": stack.size()}

		"pop":
			if stack.is_empty():
				result = {"error": "TODO stack is already empty."}
			else:
				var popped = stack.pop_back()
				context_node.todo_stack = stack
				result = {"success": true, "message": "TODO list '%s' popped from stack." % popped.title, "current_stack_depth": stack.size()}

		"update":
			if stack.is_empty():
				result = {"error": "TODO stack is empty. Use 'push' to create a list first."}
			else:
				var current_list: Dictionary = stack.back()
				var tasks: Array = current_list.tasks # Use untyped for modification
				var updated_count := 0
				
				# Add tasks
				for task_text in args.get("add_tasks", []):
					tasks.append({"text": task_text, "done": false})
					updated_count += 1
					
				# Mark done
				for index in args.get("mark_done", []):
					if index >= 0 and index < tasks.size():
						tasks[index]["done"] = true
						updated_count += 1
					else:
						return JSON.stringify({"error": "Invalid task index: %d. The list '%s' has %d tasks." % [index, current_list.title, tasks.size()]})
						
				# Mark undone
				for index in args.get("mark_undone", []):
					if index >= 0 and index < tasks.size():
						tasks[index]["done"] = false
						updated_count += 1
					else:
						return JSON.stringify({"error": "Invalid task index: %d. The list '%s' has %d tasks." % [index, current_list.title, tasks.size()]})
				
				context_node.todo_stack = stack
				result = {"success": true, "message": "TODO list '%s' updated (%d changes)." % [current_list.title, updated_count], "tasks": tasks}

		"list":
			result = {"todo_stack": stack}

		"cancel_stack":
			stack.clear()
			context_node.todo_stack = stack
			result = {"success": true, "message": "TODO stack cleared."}

		_:
			result = {"error": "Unknown operation: %s" % operation}

	return JSON.stringify(result)
