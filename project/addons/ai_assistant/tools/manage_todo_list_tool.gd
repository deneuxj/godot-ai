@tool
extends AITool

## Manage TODO lists for the AI agent.
## Allows creating, listing, updating, and deleting TODO lists persisted in a JSON file.

const TODO_FILE_PATH := "res://.ai_assistant/todos.json"

func _init() -> void:
	name = "manage_todo_list"
	description = "Create and manage TODO lists to track progress on complex tasks. Break down the user's request into smaller, manageable TODO items. Before starting implementation, create a TODO list. Mark items as done as you complete them."


func get_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"operation": {
				"type": "string",
				"enum": ["create", "list", "update", "delete"],
				"description": "The operation to perform."
			},
			"params": {
				"type": "object",
				"properties": {
					"title": {
						"type": "string",
						"description": "The title of the TODO list."
					},
					"tasks": {
						"type": "array",
						"items": { "type": "string" },
						"description": "Initial tasks for the 'create' operation."
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
				"required": ["title"]
			}
		},
		"required": ["operation", "params"]
	}


func execute(args: Dictionary) -> Variant:
	var operation: String = args.get("operation", "")
	var params: Dictionary = args.get("params", {})
	var title: String = params.get("title", "")

	if title.is_empty() and operation != "list":
		return JSON.stringify({"error": "Title is required for this operation."})

	var todos := _load_todos()

	var result: Variant = null
	match operation:
		"create":
			if todos.has(title):
				result = {"error": "A TODO list with this title already exists."}
			else:
				var tasks: Array = []
				for task_text in params.get("tasks", []):
					tasks.append({"text": task_text, "done": false})
				todos[title] = tasks
				_save_todos(todos)
				result = {"success": true, "message": "TODO list '%s' created with %d tasks." % [title, tasks.size()]}

		"list":
			if title.is_empty():
				result = {"todos": todos}
			elif not todos.has(title):
				result = {"error": "TODO list '%s' not found." % title}
			else:
				result = {"title": title, "tasks": todos[title]}

		"update":
			if not todos.has(title):
				result = {"error": "TODO list '%s' not found." % title}
			else:
				var tasks: Array = todos[title]
				var updated_count := 0
				
				# Add tasks
				for task_text in params.get("add_tasks", []):
					tasks.append({"text": task_text, "done": false})
					updated_count += 1
					
				# Mark done
				for index in params.get("mark_done", []):
					if index >= 0 and index < tasks.size():
						tasks[index]["done"] = true
						updated_count += 1
					else:
						return JSON.stringify({"error": "Invalid task index: %d. The list '%s' has %d tasks." % [index, title, tasks.size()]})
						
				# Mark undone
				for index in params.get("mark_undone", []):
					if index >= 0 and index < tasks.size():
						tasks[index]["done"] = false
						updated_count += 1
					else:
						return JSON.stringify({"error": "Invalid task index: %d. The list '%s' has %d tasks." % [index, title, tasks.size()]})
				
				todos[title] = tasks
				_save_todos(todos)
				result = {"success": true, "message": "TODO list '%s' updated (%d changes)." % [title, updated_count], "tasks": tasks}

		"delete":
			if not todos.has(title):
				result = {"error": "TODO list '%s' not found." % title}
			else:
				todos.erase(title)
				_save_todos(todos)
				result = {"success": true, "message": "TODO list '%s' deleted." % title}

		_:
			result = {"error": "Unknown operation: %s" % operation}

	return JSON.stringify(result)


func _load_todos() -> Dictionary:
	if not FileAccess.file_exists(TODO_FILE_PATH):
		return {}
	
	var file := FileAccess.open(TODO_FILE_PATH, FileAccess.READ)
	var content := file.get_as_text()
	var json = JSON.new()
	var error = json.parse(content)
	if error == OK:
		return json.data
	return {}


func _save_todos(todos: Dictionary) -> void:
	# Ensure directory exists
	var dir_path := TODO_FILE_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
		
	var file := FileAccess.open(TODO_FILE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(todos, "\t"))
