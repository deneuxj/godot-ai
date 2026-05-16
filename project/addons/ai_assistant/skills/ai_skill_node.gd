## AISkill - Represents a specialized skill for the AI agent as a Node.
##
## A skill node contains instructions, tool definitions, and implementation logic.
## It is discovered by AI nodes (like AIChat) in the scene tree.

@tool
class_name AISkillNode
extends Node

@export_group("AI Skill Metadata")

## Brief description of the skill for the discovery phase.
@export
var description: String = ""

## Detailed expert instructions for the AI (replaces SKILL.md).
@export_multiline
var definition: String = ""

## Toggles whether this skill is discoverable by the AI.
@export
var is_active: bool = true

## Array of OpenAI-compatible function schemas.
## Each element should be a Dictionary following the OpenAI tool call format:
## {
##   "type": "function",
##   "function": {
##     "name": "my_tool",
##     "description": "...",
##     "parameters": { ... }
##   }
## }
@export
var tools: Array[Dictionary] = []

func _ready() -> void:
	# Ensure the node name is unique among siblings if it's meant to be a skill ID
	pass
