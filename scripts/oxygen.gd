class_name Oxygen
extends Node3D

@export var light:OmniLight3D = null
@export var oxygen_meter:Node3D = null
@onready var ship:Ship = get_parent()

var max_light:float = 1.5

var tween:Tween = null

var online := false

var decay_rate := 0.01


func _process(delta: float) -> void:
	if !online and !ship.player.frozen:
		var actual_decay := decay_rate * delta
		var next_scale = oxygen_meter.scale.y - actual_decay
		var next_energy = light.light_energy - actual_decay
		if next_scale < 0.001:
			if ship.player and ship.player and !ship.player.frozen:
				ship.player._suffocate()
		else:
			oxygen_meter.scale.y = next_scale
			ship.player._relieve_suffocation()
		if next_energy > 0.001:
			light.light_energy = next_energy


func pump() -> void:
	if online == true: return
	if tween: tween.stop()
	tween = create_tween()
	$PumpAudio.play()
	tween.tween_property(oxygen_meter, "scale:y", clampf(oxygen_meter.scale.y + .2, .5, 1), 0.5)
	tween.tween_property(light, "light_energy", clampf(light.light_energy + .2, 0, 1), 0.1)


func release_pressure() -> void:
	if tween: tween.stop()
	online = false
	tween = create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.1)
