## AISettings - Manages AI project settings for the plugin.

class_name AISettings


const PREFIX := "ai/openai/"

# Subgroup definitions
const CONN := "connection/"
const GEN := "generation/"

static var DEFAULTS := {
	CONN + "base_url": "http://localhost:1234/v1",
	CONN + "api_key": "",
	CONN + "model": "local-model",
	GEN + "max_tokens": 4096,
	GEN + "max_retries": 5,
	GEN + "timeout_ms": 60000,
	GEN + "system_prompt": "",
}


## Ensure all project settings exist; create them if missing.
static func ensure_settings_exist() -> void:
	# 1. Register values if they don't exist
	for key in DEFAULTS:
		var full_key: String = PREFIX + key
		if not ProjectSettings.has_setting(full_key):
			ProjectSettings.set_setting(full_key, DEFAULTS[key])
		ProjectSettings.set_initial_value(full_key, DEFAULTS[key])

	# 2. Register Property Info for Editor UI
	_add_setting(CONN + "base_url", TYPE_STRING, PROPERTY_HINT_NONE, "Base URL for the AI API (e.g. http://localhost:1234/v1)")
	_add_setting(CONN + "api_key", TYPE_STRING, PROPERTY_HINT_NONE, "API Key for authentication")
	_add_setting(CONN + "model", TYPE_STRING, PROPERTY_HINT_NONE, "Model name to use")
	
	_add_setting(GEN + "max_tokens", TYPE_INT, PROPERTY_HINT_RANGE, "1,32768,1")
	_add_setting(GEN + "max_retries", TYPE_INT, PROPERTY_HINT_RANGE, "0,20,1")
	_add_setting(GEN + "timeout_ms", TYPE_INT, PROPERTY_HINT_RANGE, "1000,300000,1000")
	_add_setting(GEN + "system_prompt", TYPE_STRING, PROPERTY_HINT_MULTILINE_TEXT)

	ProjectSettings.save()


static func _add_setting(key: String, type: int, hint: int = PROPERTY_HINT_NONE, hint_string: String = "") -> void:
	var full_key := PREFIX + key
	var info := {
		"name": full_key,
		"type": type,
		"hint": hint,
		"hint_string": hint_string,
		"usage": PROPERTY_USAGE_DEFAULT
	}
	ProjectSettings.add_property_info(info)


## Get a string value from a subgroup.
static func get_string(subgroup: String, key: String) -> String:
	var full_key := PREFIX + subgroup + key
	if ProjectSettings.has_setting(full_key):
		return ProjectSettings.get_setting(full_key)
	return str(DEFAULTS.get(subgroup + key, ""))


## Get an int value from a subgroup.
static func get_int(subgroup: String, key: String) -> int:
	var full_key := PREFIX + subgroup + key
	if ProjectSettings.has_setting(full_key):
		return ProjectSettings.get_setting(full_key)
	return int(DEFAULTS.get(subgroup + key, 0))
