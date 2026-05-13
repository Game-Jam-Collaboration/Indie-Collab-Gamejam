class_name Oxygen
extends Node3D

@export var light:OmniLight3D = null

var max_light:float = 1.5

var tween:Tween = null

var online := false


func pump() -> void:
	if online == true: return
	if light.light_energy + .3 >= max_light:
		online = true
		$Online.play()
	else:
		$PumpAudio.play()
	if tween: tween.stop()
	tween = create_tween()
	tween.tween_property(light, "light_energy", light.light_energy + .3, 0.1)


func release_pressure() -> void:
	if tween: tween.stop()
	tween = create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.1)
	online = false
