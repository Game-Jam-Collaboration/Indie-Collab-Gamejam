class_name FusePanel
extends Area3D

@export var environment_light:Light3D = null
@export var emissive_object:MeshInstance3D
@export var emissive_material_idx:int = 0
@export var status_panel: AssemblyStatusPanel = null
@export var slot_index: int = 0
@export var can_remove_fuse: bool = false
@export var fuse:RigidBody3D = null
@export var audio:AudioStreamPlayer3D = null
@export var holodeck:Node3D = null
@export var heater:Node3D = null
@export var cabin_lights: Array[Light3D] = []
## Lights affected by the end-game chaos flicker (ramps in frequency and
## intensity as the angels close in). Typically the cabin lights plus radar,
## oxygen, and fuse-panel indicators.
@export var chaos_flicker_lights: Array[Light3D] = []
## Loud impact sound used when the fuse gets violently ejected during the
## end-game (initial shutdown + every locked-out re-insertion auto-eject).
@export var entity_attack_audio: AudioStreamPlayer3D = null

var online := false
var locked_out := false
const ENDGAME_REPOWER_DURATION: float = 1.0
const CHAOS_FLICKER_DURATION: float = 18.0
const CHAOS_TICK_SLOW: float = 0.22
const CHAOS_TICK_FAST: float = 0.09
## File offset into the EntityAttack stream — the actual boom hits ~1.0s in.
## Initial shutdown wants the boom immediately (skip the entire lead-in);
## the re-insert eject wants a slight delay after the visible eject moment.
const ENTITY_ATTACK_OFFSET_INITIAL: float = 1.0
const ENTITY_ATTACK_OFFSET_REPLUG: float = 0.4

var offline_light_color:Color = Color.FIREBRICK
var online_light_color:Color = Color.FOREST_GREEN

var offline_emissive:StandardMaterial3D = load("res://assets/materials/offline_emissive.tres")
var online_emissive:StandardMaterial3D = load("res://assets/materials/online_emissive.tres")

var _cabin_base_energies: Array[float] = []
var _cabin_tweens: Array[Tween] = []
var _chaos_base_energies: Dictionary = {}
var _chaos_active: bool = false
var _chaos_elapsed: float = 0.0
var _chaos_tick_accum: float = 0.0


func _ready() -> void:
	for light in cabin_lights:
		if light == null:
			_cabin_base_energies.append(0.0)
			continue
		_cabin_base_energies.append(light.light_energy)
	# Capture chaos baselines before we zero anything out — cabin entries reuse
	# their captured base above so a single light listed in both arrays gets the
	# right reference brightness.
	for light in chaos_flicker_lights:
		if light == null or _chaos_base_energies.has(light):
			continue
		var cabin_idx: int = cabin_lights.find(light)
		if cabin_idx >= 0 and cabin_idx < _cabin_base_energies.size():
			_chaos_base_energies[light] = _cabin_base_energies[cabin_idx]
		else:
			_chaos_base_energies[light] = light.light_energy
	# Game starts powered-off; reflect that on the cabin lights too.
	for light in cabin_lights:
		if light != null:
			light.light_energy = 0.0


func assemble() -> void:
	if status_panel:
		status_panel.mark_complete(slot_index)
	online = true
	_change_lighting()
	_surge_cabin_lights()
	if locked_out:
		# End-game: the entity-attack boom takes the place of the normal
		# assembly click so the audio lands at the moment of insertion, not 1s
		# later. Mirrors the mid-game attack timing (sound first, eject after).
		_play_entity_attack(ENTITY_ATTACK_OFFSET_REPLUG)
	elif audio:
		audio.pitch_scale = randf_range(0.95, 1.05)
		audio.play()
	if heater:
		heater.online = true
	if holodeck:
		holodeck.get_node("%Powered").visible = true
		holodeck.get_node("%RadarSound").play()
		holodeck.get_node("%LidarRenderer").update_lidar()
	if locked_out:
		# Let the player feel power restore for a beat, then forcibly blow the
		# fuse back out (light goes red, cabin flicker-cuts).
		await get_tree().create_timer(ENDGAME_REPOWER_DURATION).timeout
		if online:
			disassemble()


func end_game_shutdown() -> void:
	# Cut power and arm the lockout so any subsequent re-power attempt
	# auto-disassembles after a brief moment. Then kick off the angel-approach
	# chaos flicker on the major lights.
	locked_out = true
	_play_entity_attack(ENTITY_ATTACK_OFFSET_INITIAL)
	disassemble()
	_start_chaos_flicker()


func _play_entity_attack(offset: float) -> void:
	# The shared EntityAttack stream has lead-in before the actual boom —
	# callers pick an offset so the impact lands when they want it relative to
	# the eject frame.
	if entity_attack_audio != null:
		entity_attack_audio.play(offset)


func _start_chaos_flicker() -> void:
	_chaos_active = true
	_chaos_elapsed = 0.0
	_chaos_tick_accum = 0.0


func _update_chaos_flicker(delta: float) -> void:
	# Time advances even while paused (online) so the intensity curve stays
	# tied to real time, mirroring how close the angels are.
	_chaos_elapsed += delta
	if online:
		return
	var t: float = clampf(_chaos_elapsed / CHAOS_FLICKER_DURATION, 0.0, 1.0)
	var tick_interval: float = lerpf(CHAOS_TICK_SLOW, CHAOS_TICK_FAST, t)
	_chaos_tick_accum += delta
	if _chaos_tick_accum < tick_interval:
		return
	_chaos_tick_accum = 0.0
	var lit_chance: float = lerpf(0.12, 0.7, t)
	var max_mult: float = lerpf(0.35, 1.8, t)
	for light in _chaos_base_energies.keys():
		if light == null:
			continue
		var base: float = _chaos_base_energies[light]
		if randf() < lit_chance:
			light.light_energy = base * randf_range(0.3, max_mult)
		else:
			light.light_energy = 0.0


func disassemble() -> void:
	if !online: return
	_power_off()
	if fuse:
		fuse.freeze = false
		# Double the ejection force during the end-game so the fuse really
		# launches when the entity rejects it.
		var force_mult: float = 2.0 if locked_out else 1.0
		fuse.apply_central_impulse(Vector3(-2.0 * force_mult, 0, 0))
		fuse.apply_torque_impulse(Vector3(randf_range(-.5, .5) * force_mult, 0, 0))
		fuse.add_to_group("Pickupable")


func _power_off() -> void:
	if !online: return
	if status_panel:
		status_panel.mark_pending(slot_index)
	online = false
	_change_lighting()
	_flicker_then_cut_cabin_lights()
	if heater:
		heater.online = false
	if holodeck:
		holodeck.get_node("%Powered").visible = false
		holodeck.get_node("%RadarSound").stop()


func _kill_cabin_tweens() -> void:
	for t in _cabin_tweens:
		if t != null and t.is_running():
			t.kill()
	_cabin_tweens.clear()


func _flicker_then_cut_cabin_lights() -> void:
	if cabin_lights.is_empty():
		return
	_kill_cabin_tweens()
	for i in cabin_lights.size():
		var light: Light3D = cabin_lights[i]
		if light == null:
			continue
		var base: float = _cabin_base_energies[i] if i < _cabin_base_energies.size() else light.light_energy
		var dim: float = base * 0.15
		var sub := create_tween()
		# Two quick dim-bright blinks then a hard cut to zero.
		sub.tween_property(light, "light_energy", dim, 0.05)
		sub.tween_property(light, "light_energy", base, 0.05)
		sub.tween_property(light, "light_energy", dim, 0.07)
		sub.tween_property(light, "light_energy", base, 0.05)
		sub.tween_property(light, "light_energy", 0.0, 0.12)
		_cabin_tweens.append(sub)


func _surge_cabin_lights() -> void:
	if cabin_lights.is_empty():
		return
	_kill_cabin_tweens()
	for i in cabin_lights.size():
		var light: Light3D = cabin_lights[i]
		if light == null:
			continue
		var base: float = _cabin_base_energies[i] if i < _cabin_base_energies.size() else 1.0
		var overshoot: float = base * 1.2
		var sub := create_tween()
		sub.tween_property(light, "light_energy", overshoot, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		sub.tween_property(light, "light_energy", base, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_cabin_tweens.append(sub)


func _process(delta: float) -> void:
	if online and not _has_assembled_fuse():
		_power_off()
	if _chaos_active:
		_update_chaos_flicker(delta)


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


func can_remove() -> bool:
	return can_remove_fuse and _has_assembled_fuse()


func _has_assembled_fuse() -> bool:
	var ap := get_node_or_null("AssemblyPoint")
	return ap != null and ap.get_child_count() > 0


func release_assembled() -> CollisionObject3D:
	var ap := get_node_or_null("AssemblyPoint")
	if ap == null or ap.get_child_count() == 0:
		return null
	var _fuse := ap.get_child(0) as CollisionObject3D
	if _fuse == null:
		return null
	if status_panel:
		status_panel.mark_pending(slot_index)
	_change_lighting()
	return _fuse
