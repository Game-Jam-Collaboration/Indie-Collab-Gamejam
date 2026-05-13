class_name Oxygen
extends Node3D

@export var light:OmniLight3D = null
@export var environment_light:Light3D = null
@export var emissive_object:MeshInstance3D
@export var emissive_material_idx:int = 1

var offline_light_color:Color = Color.FIREBRICK
var online_light_color:Color = Color.FOREST_GREEN
var offline_emissive:StandardMaterial3D = load("res://assets/materials/offline_emissive.tres")
var online_emissive:StandardMaterial3D = load("res://assets/materials/online_emissive.tres")

var max_light:float = 1.5

var tween:Tween = null

var online := false


func _change_lighting() -> void:
	if !online:
		if environment_light:
			environment_light.light_color = offline_light_color
		if emissive_object:
			emissive_object.mesh.surface_set_material(emissive_material_idx, offline_emissive)
	else:
		if environment_light:
			environment_light.light_color = online_light_color
		if emissive_object:
			emissive_object.mesh.surface_set_material(emissive_material_idx, online_emissive)


func pump() -> void:
	if online == true: return
	if light.light_energy + .75 >= max_light:
		online = true
		$Online.play()
		_change_lighting()
	else:
		$PumpAudio.play()
	if tween: tween.stop()
	tween = create_tween()
	tween.tween_property(light, "light_energy", light.light_energy + .75, 0.1)


func release_pressure() -> void:
	if tween: tween.stop()
	online = false
	tween = create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.1)
	_change_lighting()
