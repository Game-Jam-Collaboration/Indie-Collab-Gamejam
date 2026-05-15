class_name Oxygen
extends Node3D

const SUFFOCATION_BLINK_PERIOD: float = 0.45
const SUFFOCATION_RED_ON: Color = Color(1.0, 0.1, 0.1, 1.0)
const SUFFOCATION_RED_OFF: Color = Color(0.15, 0.0, 0.0, 1.0)

@export var light:OmniLight3D = null
@export var oxygen_meter:Node3D = null
@onready var ship:Ship = get_parent()

var max_light:float = 1.5

var tween:Tween = null

var online := false

var decay_rate := 0.01

var _suffocation_blink_timer: float = 0.0
var _suffocation_active: bool = false
var _normal_light_color: Color = Color.WHITE
var _normal_light_color_captured: bool = false


func _process(delta: float) -> void:
	if ship.player.suffocating:
		_drive_suffocation_blink(delta)
		return
	if _suffocation_active:
		_restore_light_color()
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


func _drive_suffocation_blink(delta: float) -> void:
	if light == null:
		return
	if not _suffocation_active:
		_suffocation_active = true
		if not _normal_light_color_captured:
			_normal_light_color = light.light_color
			_normal_light_color_captured = true
		if tween:
			tween.stop()
	_suffocation_blink_timer += delta
	var on: bool = fmod(_suffocation_blink_timer, SUFFOCATION_BLINK_PERIOD) < SUFFOCATION_BLINK_PERIOD * 0.5
	light.light_color = SUFFOCATION_RED_ON if on else SUFFOCATION_RED_OFF
	light.light_energy = 1.4 if on else 0.05


func _restore_light_color() -> void:
	_suffocation_active = false
	_suffocation_blink_timer = 0.0
	if light != null and _normal_light_color_captured:
		light.light_color = _normal_light_color


func pump() -> void:
	if online == true: return
	if tween: tween.stop()
	tween = create_tween()
	$PumpAudio.play()
	tween.tween_property(oxygen_meter, "scale:y", clampf(oxygen_meter.scale.y + .2, .5, 1), 0.5)
	tween.tween_property(light, "light_energy", clampf(light.light_energy + .2, 0, 1), 0.1)
	if ship and ship.player and ship.player.suffocating:
		ship.player._relieve_suffocation()


func release_pressure() -> void:
	if tween: tween.stop()
	online = false
	tween = create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.1)
