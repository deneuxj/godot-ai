## AISettings - Manages AI project settings for the plugin.

class_name AISettings


const PREFIX := "ai/openai/"

static var DEFAULTS := {
	"base_url": "http://localhost:1234/v1",
	"api_key": "",
	"model": "local-model",
	"max_tokens": 4096,
	"max_retries": 5,
	"timeout_ms": 60000,
}


## Ensure all project settings exist; create them if missing.
static func ensure_settings_exist() -> void:
	for key in DEFAULTS:
		var full_key: String = PREFIX + str(key)
		if not ProjectSettings.has_setting(full_key):
			ProjectSettings.set_setting(full_key, DEFAULTS[key])
		ProjectSettings.set_initial_value(full_key, DEFAULTS[key])

	# Optional system prompt (no default value)
	if not ProjectSettings.has_setting(PREFIX + "system_prompt"):
		ProjectSettings.set_setting(PREFIX + "system_prompt", "")
		ProjectSettings.set_initial_value(PREFIX + "system_prompt", "")

	ProjectSettings.save()


## Get a string-valued setting, falling back to the default if unset.
static func get_string(key: String) -> String:
	var full_key := PREFIX + key
	if ProjectSettings.has_setting(full_key):
		return ProjectSettings.get_setting(full_key)
	return str(DEFAULTS.get(key, ""))


## Get an int-valued setting, falling back to the default if unset.
static func get_int(key: String) -> int:
	var full_key := PREFIX + key
	if ProjectSettings.has_setting(full_key):
		return ProjectSettings.get_setting(full_key)
	return int(DEFAULTS.get(key, 0))
