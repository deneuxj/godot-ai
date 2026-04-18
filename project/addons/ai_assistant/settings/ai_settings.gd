## AISettings - Manages AI project settings for the plugin.
##
## Auto-creates settings on plugin enable if they don't exist.

class_name AISettings


static var DEFAULTS := {
	"base_url": "http://localhost:1234/v1",
	"api_key": "",
	"model": "local-model",
	"max_tokens": 4096,
	"timeout_ms": 60000,
}


static func ensure_settings_exist() -> void:
	for key in DEFAULTS:
		var setting = "ai/openai/" + key
		if not ProjectSettings.has_setting(setting):
			ProjectSettings.set_setting(setting, DEFAULTS[key])
			ProjectSettings.set_initial_value(setting, DEFAULTS[key])

	if not ProjectSettings.has_setting("ai/openai/system_prompt"):
		ProjectSettings.set_setting("ai/openai/system_prompt", "")
		ProjectSettings.set_initial_value("ai/openai/system_prompt", "")

	ProjectSettings.save()


static func get_string(key: String) -> String:
	return ProjectSettings.get_setting("ai/openai/" + key, DEFAULTS[key])


static func get_int(key: String) -> int:
	return ProjectSettings.get_setting("ai/openai/" + key, DEFAULTS[key])


static func get_float(key: String) -> float:
	return ProjectSettings.get_setting("ai/openai/" + key, float(DEFAULTS[key]))
