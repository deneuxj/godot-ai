## AISkill - Represents a specialized skill for the AI agent as a Node.
##
## A skill node contains instructions, tool definitions, and implementation logic.
## It is discovered by AI nodes (like AIChat) in the scene tree.
##
## [b]CRITICAL FOR AI GENERATION:[/b]
## 1. When creating a subclass of AISkillNode via script, you MUST initialize 
##    the 'description', 'definition', and 'tools' variables inside the 
##    [code]_init()[/code] function. Do NOT assign them in the class body.
## 2. To instantiate a new skill in the scene, you should use the 
##    [code]SkillCreatorNode[/code] skill (use [code]activate_skill("SkillCreatorNode")[/code] 
##    to see the full two-step workflow).

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
