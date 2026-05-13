@tool
extends Node3D

var heater_element_on_material = load("res://assets/materials/heater_element_on.tres")
var heater_element_off_material = load("res://assets/materials/heater_element_off.tres")

@export var environment_light:Light3D = null
@export var emissive_object:MeshInstance3D
@export var emissive_material_idx:int = 1

var offline_light_color:Color = Color.FIREBRICK
var online_light_color:Color = Color.FOREST_GREEN
var offline_emissive:StandardMaterial3D = load("res://assets/materials/offline_emissive.tres")
var online_emissive:StandardMaterial3D = load("res://assets/materials/online_emissive.tres")


var tween:Tween = null

@export var online := false:
	set(value):
		if value == online: return
		if $PowerOn.playing:
			$PowerOn.stop()
		if $PowerDown.playing:
			$PowerDown.stop()
		online = value
		if tween: tween.stop()
		tween = create_tween()
		_change_lighting()
		if online:
			tween.tween_property(
				$Mesh.get_surface_override_material(3),
				"emission_energy_multiplier",
				15,
				5.6
			)
			$PowerOn.play()
		else:
			tween.tween_property(
				$Mesh.get_surface_override_material(3),
				"emission_energy_multiplier",
				0,
				.2
			)
			$PowerDown.play()


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
