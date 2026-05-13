@tool
class_name HeaterLever
extends Node3D

@export_tool_button("Test Toggle") var test_toggle = _interact
@export var heater_light:OmniLight3D = null
@export var fuse_panel:FusePanel = null
@onready var heater = get_parent()

var light_tween:Tween = null

var lever_anim = load("res://assets/animations/heater_lever.res")


var online := false


func _ready() -> void:
	heater.online = online
	heater_light.light_energy = 0.0
	%AnimationPlayer.play("heater_lever")


func _interact(force:bool=false) -> void:
	if online and !force or !fuse_panel.online: return
	if light_tween:
		light_tween.stop()
	light_tween = create_tween()
	if !online:
		%AnimationPlayer.play_backwards("heater_lever")
		%AudioStreamPlayer3D.play()
		light_tween.tween_property(heater_light, "light_energy", 1.0, 5.6)
	else:
		%AnimationPlayer.play("heater_lever")
		light_tween.tween_property(heater_light, "light_energy", 0.0, .4)
	online = not online
	heater.online = online
