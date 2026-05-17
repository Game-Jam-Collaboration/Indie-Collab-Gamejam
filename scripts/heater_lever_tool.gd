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
	if Engine.is_editor_hint():
		return
	if heater_light == null:
		heater_light = get_parent().get_node_or_null("OmniLight3D") as OmniLight3D
	if fuse_panel == null:
		fuse_panel = get_node_or_null("../../PowerPanel") as FusePanel
	if heater:
		heater.online = online
	if heater_light:
		heater_light.light_energy = 0.0
	%AnimationPlayer.play("heater_lever")


func _interact(force:bool=false) -> void:
	if online and !force: return
	if fuse_panel == null or !fuse_panel.online: return
	if light_tween:
		light_tween.stop()
	light_tween = create_tween()
	if !online:
		%AnimationPlayer.play_backwards("heater_lever")
		%AudioStreamPlayer3D.pitch_scale = randf_range(0.95, 1.05)
		%AudioStreamPlayer3D.play()
		if heater_light:
			light_tween.tween_property(heater_light, "light_energy", 1.0, 5.6)
	else:
		%AnimationPlayer.play("heater_lever")
		if heater_light:
			light_tween.tween_property(heater_light, "light_energy", 0.0, .4)
	online = not online
	if heater:
		heater.online = online
