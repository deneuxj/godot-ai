## SkillManager - Manages discovery and indexing of AI Skills.

class_name SkillManager
extends Object

const BUILTIN_PATH = "res://addons/ai_assistant/skills/"
const PROJECT_PATH = "res://ai_skills/"

## Cache of discovered skills: id -> AISkill
static var _skills: Dictionary = {}


## Scans both builtin and project directories for skills.
static func refresh_skills() -> void:
	_skills.clear()
	
	# Order matters for precedence (Project overrides Builtin)
	_scan_directory(BUILTIN_PATH)
	_scan_directory(PROJECT_PATH)


## Returns a skill by its ID.
static func get_skill(p_id: String) -> RefCounted:
	if _skills.is_empty():
		refresh_skills()
	return _skills.get(p_id)


## Returns all discovered skills.
static func get_all_skills() -> Array:
	if _skills.is_empty():
		refresh_skills()
	var result: Array = []
	for skill in _skills.values():
		result.append(skill)
	return result


static func _scan_directory(p_path: String) -> void:
	if not DirAccess.dir_exists_absolute(p_path):
		return
		
	var dir = DirAccess.open(p_path)
	dir.list_dir_begin()
	var sub_dir = dir.get_next()
	while sub_dir != "":
		if dir.current_is_dir() and not sub_dir.begins_with("."):
			var full_path = p_path.path_join(sub_dir)
			var skill_script = load("res://addons/ai_assistant/skills/ai_skill.gd")
			var skill = skill_script.from_path(full_path)
			if skill:
				_skills[skill.id] = skill
		sub_dir = dir.get_next()
