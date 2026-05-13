@tool
extends Node3D

@export_tool_button("Test Toggle") var test_toggle = _interact

@onready var heater = get_parent()

var lever_anim = load("res://assets/animations/heater_lever.res")


var offline := false

func _interact() -> void:
	heater.online = offline
	if offline:
		%AnimationPlayer.play_backwards("heater_lever")
		%AudioStreamPlayer3D.play()
	else:
		%AnimationPlayer.play("heater_lever")
	offline = not offline
