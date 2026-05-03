## AISettings - Manages AI project settings for the plugin.

class_name AISettings

# Subgroup paths
const CONN := "ai/connection/"
const GEN := "ai/generation/"


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
