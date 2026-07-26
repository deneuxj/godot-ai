## AISettings - Manages AI project settings for the plugin.

# REQ-EDITOR-0003: Configure API keys via Editor Settings or Project Settings
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
