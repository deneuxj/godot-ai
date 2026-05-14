## AISkill - Represents a specialized skill for the AI agent.
##
## A skill is a directory containing a SKILL.md for instructions,
## a tools/ directory for GDScript tools, and an optional examples/ directory.

class_name AISkill
extends RefCounted

## The unique identifier of the skill (folder name).
var id: String = ""

## Brief description of the skill for the discovery phase.
var description: String = ""

## The full path to the skill directory.
var path: String = ""

## The expert instructions from SKILL.md.
var instructions: String = ""

## Paths to the tool scripts found in the skill's tools/ directory.
var tool_scripts: Array[String] = []


## Loads a skill from a directory path.
static func from_path(p_path: String) -> RefCounted:
	if not DirAccess.dir_exists_absolute(p_path):
		return null
		
	var skill = load("res://addons/ai_assistant/skills/ai_skill.gd").new()
	skill.path = p_path
	skill.id = p_path.get_file()
	
	# Load SKILL.md
	var md_path = p_path.path_join("SKILL.md")
	if FileAccess.file_exists(md_path):
		var file = FileAccess.open(md_path, FileAccess.READ)
		skill.instructions = file.get_as_text()
		
		# Extract first line or specific marker for description
		var lines = skill.instructions.split("\n")
		for line in lines:
			line = line.strip_edges()
			if line.begins_with("# "):
				skill.description = line.trim_prefix("# ").strip_edges()
				break
	
	if skill.description.is_empty():
		skill.description = "Specialized capabilities for " + skill.id
		
	# Scan for tools
	var tools_path = p_path.path_join("tools")
	if DirAccess.dir_exists_absolute(tools_path):
		var dir = DirAccess.open(tools_path)
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".gd"):
				skill.tool_scripts.append(tools_path.path_join(file_name))
			file_name = dir.get_next()
			
	return skill
