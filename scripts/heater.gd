@tool
extends Node3D

var heater_element_on_material = load("res://assets/materials/heater_element_on.tres")
var heater_element_off_material = load("res://assets/materials/heater_element_off.tres")
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
