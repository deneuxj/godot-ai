## AISettings - Manages AI project settings for the plugin.

# REQ-EDITOR-0003: Configure API keys via Editor Settings and Environment Variables
class_name AISettings

# Subgroup paths
# REQ-AIINTG-0004: Configuration under ai/connection/ and ai/generation/
# REQ-AIINTG-0006: Configurable max_retries in ai/generation/
const CONN := "ai/connection/"
# REQ-PERSIST-0002: Hard token threshold config in settings
const GEN := "ai/generation/"
const TOOLS := "ai/tools/"


## Get a string value from a subgroup.
static func get_string(subgroup: String, key: String) -> String:
	var full_key := subgroup + key
	if ProjectSettings.has_setting(full_key):
		return str(ProjectSettings.get_setting(full_key))
	return ""


## Get an int value from a subgroup.
static func get_int(subgroup: String, key: String) -> int:
	var full_key := subgroup + key
	if ProjectSettings.has_setting(full_key):
		return int(ProjectSettings.get_setting(full_key))
	return 0

## Get a bool value from a subgroup.
static func get_bool(subgroup: String, key: String, default_value: bool = false) -> bool:
	var full_key := subgroup + key
	if ProjectSettings.has_setting(full_key):
		return bool(ProjectSettings.get_setting(full_key))
	return default_value

## Get the API key from environment variables or Editor Settings.
static func get_api_key() -> String:
	# Check .env file first
	if FileAccess.file_exists("res://.env"):
		var f = FileAccess.open("res://.env", FileAccess.READ)
		if f:
			while not f.eof_reached():
				var line = f.get_line().strip_edges()
				if line.begins_with("OPENAI_API_KEY=") or line.begins_with("AI_API_KEY="):
					var val = line.split("=", true, 1)[1].strip_edges().trim_prefix("\"").trim_suffix("\"")
					if not val.is_empty() and val != "none":
						return val
						
	var env_key = OS.get_environment("OPENAI_API_KEY")
	if not env_key.is_empty() and env_key != "none":
		return env_key
		
	env_key = OS.get_environment("AI_API_KEY")
	if not env_key.is_empty() and env_key != "none":
		return env_key
					
	if Engine.is_editor_hint():
		var editor_settings = EditorInterface.get_editor_settings()
		if editor_settings and editor_settings.has_setting("ai/connection/api_key"):
			return str(editor_settings.get_setting("ai/connection/api_key"))
			
	return ""
