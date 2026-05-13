@tool
extends Node3D

@export_tool_button("Test Toggle") var test_toggle = _interact
@export var heater_light:OmniLight3D = null
@onready var heater = get_parent()

var lever_anim = load("res://assets/animations/heater_lever.res")


var offline := false

func _interact(force:bool=false) -> void:
	#if offline and !force: return
	heater.online = offline
	var light_tween = create_tween()
	if offline:
		%AnimationPlayer.play_backwards("heater_lever")
		%AudioStreamPlayer3D.play()
		light_tween.tween_property(heater_light, "light_energy", 1.0, 5.6)
	else:
		%AnimationPlayer.play("heater_lever")
		light_tween.tween_property(heater_light, "light_energy", 0.0, .4)
	offline = not offline
