## AISettings - Manages AI project settings for the plugin.

class_name AISettings


static var DEFAULTS := {
	"base_url": "http://localhost:1234/v1",
	"api_key": "",
	"model": "local-model",
	"max_tokens": 4096,
	"timeout_ms": 60000,
}


static func ensure_settings_exist() -> void:
	pass


static func get_string(key: String) -> String:
	return ""


static func get_int(key: String) -> int:
	return 0
