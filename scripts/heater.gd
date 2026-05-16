@tool
extends Node3D

var heater_element_on_material = load("res://assets/materials/heater_element_on.tres")
var heater_element_off_material = load("res://assets/materials/heater_element_off.tres")
@export var heater_light:OmniLight3D = null


var tween:Tween = null
var light_tween:Tween = null

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
		if light_tween: light_tween.stop()
		light_tween = create_tween()
		if online:
			tween.tween_property(
				$Mesh.get_surface_override_material(3),
				"emission_energy_multiplier",
				15,
				5.6
			)
			$PowerOn.play()
			light_tween.tween_property(heater_light, "light_energy", 1.0, 5.6)

		else:
			tween.tween_property(
				$Mesh.get_surface_override_material(3),
				"emission_energy_multiplier",
				0,
				.2
			)
			$PowerDown.play()

			light_tween.tween_property(heater_light, "light_energy", 0.0, .4)
