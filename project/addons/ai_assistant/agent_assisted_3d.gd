## AgentAssisted3D - Custom 3D node that generates a scene subtree via AI.

@tool
extends Node3D


class_name AgentAssisted3D


enum GenerationStatus {
	IDLE = 0,
	GENERATING = 1,
	SUCCESS = 2,
	ERROR = 3,
}


signal generation_started()
signal generation_finished()
signal progress(chunks: Array[String])


@export_group("AI Assistant")

@export_multiline
var prompt: String = ""

@export
var texture_attachments: Array[Texture2D] = []

@export
var generation_status: GenerationStatus = GenerationStatus.IDLE

@export
var status_message: String = ""

@export
var api_endpoint: String = ""

@export
var api_key: String = ""

@export
var model: String = ""


func generate() -> void:
	pass


func force_generate() -> void:
	pass
