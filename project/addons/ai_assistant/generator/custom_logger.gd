## CustomLogger - Intercepts Godot engine errors for the AI Assistant.
##
## This logger captures internal engine messages and errors, allowing the
## validation loop to provide detailed feedback to the AI.

extends Logger

var captured_errors: Array[String] = []
var is_capturing: bool = false

func _log_message(message: String, is_error: bool) -> void:
	if is_capturing and is_error:
		captured_errors.append(message.strip_edges())

func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array) -> void:
	if is_capturing:
		var type_str = "ERROR" if error_type == 1 else "WARNING"
		var msg = "[%s] %s (at %s:%d in %s)" % [type_str, rationale, file, line, function]
		captured_errors.append(msg)

func start_capture() -> void:
	captured_errors.clear()
	is_capturing = true

func stop_capture() -> void:
	is_capturing = false

func get_captured_errors() -> String:
	return "\n".join(captured_errors)
