@tool
extends Node3D

var heater_element_on_material = load("res://assets/materials/heater_element_on.tres")
var heater_element_off_material = load("res://assets/materials/heater_element_off.tres")


@export var online := true:
	set(value):
		if value == online: return
		online = value
		var tween = create_tween()
		if online:
			tween.tween_property(
				$Mesh.get_surface_override_material(3),
				"emission_energy_multiplier",
				5,
				1.3
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
