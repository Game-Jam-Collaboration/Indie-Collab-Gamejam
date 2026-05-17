class_name RecordButton
extends Node3D

@export var navigation: ShipNavigation = null
@export var detection_range: float = 25.0
@export var indicator_light: MeshInstance3D = null
@export var indicator_off_material: Material = null
@export var indicator_on_material: Material = null
@export var indicator_recording_material: Material = null
@export var cover: Node3D = null
@export var cover_open_angle_deg: float = 100.0
@export var cover_anim_speed: float = 5.0
@export var flash_period: float = .8
@export var progress_lights: Array[MeshInstance3D] = []
@export var progress_light_off_material: Material = null
@export var progress_light_on_material: Material = null

@onready var player:Player = get_parent().player

var anomaly_tracks:Array[AudioStream] = [
	load("res://assets/sounds/Anomaly - Record/SFX_AnomalyEncounter-Loud-5.wav"),
	load("res://assets/sounds/Anomaly - Ship contact/SFX_Anomaly-ShipContact-0.wav"),
	load("res://assets/sounds/CJ26_SFX_Anomaly-ShipContact-1.wav"),
	load("res://assets/sounds/CJ26_SFX_AnomalyEncounter-5.wav"),
	load("res://assets/sounds/CJ26_SFX_Anomaly-ShipContact_proto_mix.wav"),
]

var anomalies_recorded:int = 0
var speed_multiplier: float = 1.0:
	set(value):
		speed_multiplier = value
		_apply_speed_to_recording()

var _current_anomaly: Anomaly = null
var _cover_rest_basis: Basis = Basis.IDENTITY
var _cover_open: float = 0.0
var _flash_timer: float = 0.0
var _light_on: bool = false
var recording := false
var _cover_open_audio: AudioStreamPlayer3D = null
const COVER_OPEN_STREAM := preload("res://assets/sounds/SFX_ActivationFusible.wav")


func _ready() -> void:
	add_to_group("record_button")
	if cover:
		_cover_rest_basis = cover.transform.basis
	_set_light(false)
	_build_cover_feedback()


func _resolve_navigation() -> void:
	if navigation == null:
		navigation = get_tree().get_first_node_in_group("ship_navigation") as ShipNavigation


func _process(delta: float) -> void:
	_resolve_navigation()
	_update_target()
	var want_open := _current_anomaly != null
	var prev_open := _cover_open
	_cover_open = move_toward(_cover_open, 1.0 if want_open else 0.0, cover_anim_speed * delta)
	if prev_open <= 0.001 and _cover_open > 0.001:
		_play_cover_open_feedback()
	_apply_cover_rotation()
	if recording:
		_update_flash(delta)
	else:
		_set_light(want_open)
	_update_progress_lights()


func _interact() -> void:
	if _current_anomaly == null or recording: return
	var anomaly = _current_anomaly
	_current_anomaly = null
	anomaly.being_recorded = true
	await get_tree().process_frame
	recording = true
	_apply_speed_to_recording()
	%AnomalyRecording.stream = anomaly_tracks[anomalies_recorded]
	%AnomalyRecording.play()
	await %AnomalyRecording.finished
	anomaly.being_recorded = false
	anomaly.recorded = true
	recording = false
	anomalies_recorded += 1
	_on_anomalies_recorded_changed()


func _apply_speed_to_recording() -> void:
	if not is_inside_tree() or not has_node("AnomalyRecording"):
		return
	%AnomalyRecording.pitch_scale = max(speed_multiplier, 0.01)


func debug_skip_to_endgame() -> void:
	# Mark the first 4 anomalies as fully recorded, leave the 5th idle.
	var marked: int = 0
	for node in get_tree().get_nodes_in_group("anomaly"):
		var anom := node as Anomaly
		if anom == null:
			continue
		if marked < 4:
			anom.being_recorded = false
			anom.recorded = true
			marked += 1
	anomalies_recorded = 4
	_on_anomalies_recorded_changed()


func play_end_game_audio() -> void:
	if not is_inside_tree() or not has_node("AnomalyRecording"):
		return
	if recording:
		return
	%AnomalyRecording.stream = anomaly_tracks[4]
	%AnomalyRecording.play()


func get_recording_progress() -> float:
	if not recording or not is_inside_tree() or not has_node("AnomalyRecording"):
		return 0.0
	var p: AudioStreamPlayer3D = %AnomalyRecording
	if p.stream == null:
		return 0.0
	var length: float = p.stream.get_length()
	if length <= 0.0:
		return 0.0
	return clampf(p.get_playback_position() / length, 0.0, 1.0)


func _on_anomalies_recorded_changed() -> void:
	if anomalies_recorded == 3:
		var lidar := get_tree().get_first_node_in_group("lidar_renderer")
		if lidar != null and lidar.has_method("trigger_glitch_burst"):
			lidar.trigger_glitch_burst(5.0)
		else:
			push_warning("RecordButton: lidar_renderer group missing; glitch burst skipped")
		# Glitch covers Anomaly 5 leaping out to the far horizon — its eventual
		# approach will then be a long, ominous trek instead of an instant pop-in.
		for node in get_tree().get_nodes_in_group("anomaly"):
			var anom := node as Anomaly
			if anom != null and anom.anomaly_id == "ANOM-05":
				anom.position = Vector3(-196.0, 0.0, -40.0)
	if anomalies_recorded == 4:
		for node in get_tree().get_nodes_in_group("anomaly"):
			var anom := node as Anomaly
			if anom != null and not anom.recorded:
				await get_tree().create_timer(2).timeout
				anom.chasing = true


func _update_target() -> void:
	_current_anomaly = null
	if navigation == null: return
	# After the 4th recording the last anomaly is unrecordable — no targeting,
	# so the cover stays shut and the button can't be pressed.
	if anomalies_recorded >= 4: return
	var closest := detection_range
	for node in get_tree().get_nodes_in_group("anomaly"):
		var anom := node as Anomaly
		if anom == null or anom.recorded or anom.being_recorded: continue
		var d := anom.position.distance_to(navigation.simulated_position)
		if d <= closest:
			closest = d
			_current_anomaly = anom


func _apply_cover_rotation() -> void:
	if cover == null: return
	var angle := deg_to_rad(cover_open_angle_deg) * _cover_open
	var t := cover.transform
	t.basis = _cover_rest_basis * Basis(Vector3(0, 0, 1), angle)
	cover.transform = t


func _update_flash(delta: float) -> void:
	var mat := indicator_recording_material
	if mat != null: indicator_light.material_override = mat
	if not recording:
		if _light_on:
			_set_light(false)
		_flash_timer = 0.0
		return
	_flash_timer += delta
	if _flash_timer >= flash_period * 0.5:
		_flash_timer = 0.0
		_set_light(not _light_on)


func _set_light(on: bool) -> void:
	_light_on = on
	if indicator_light == null: return
	var mat := indicator_on_material if on else indicator_off_material
	if mat != null: indicator_light.material_override = mat


func _build_cover_feedback() -> void:
	# Mechanical click — repurposes the fuse activation sample at a higher pitch
	# so it reads as a cover unlatching instead of an electrical clunk.
	_cover_open_audio = AudioStreamPlayer3D.new()
	_cover_open_audio.stream = COVER_OPEN_STREAM
	_cover_open_audio.unit_size = 4.0
	_cover_open_audio.max_db = 0.0
	_cover_open_audio.volume_db = -6.0
	add_child(_cover_open_audio)
	if cover:
		_cover_open_audio.transform.origin = cover.transform.origin


func _play_cover_open_feedback() -> void:
	if _cover_open_audio != null:
		_cover_open_audio.pitch_scale = randf_range(0.875, 1.085)
		_cover_open_audio.play()


func _update_progress_lights() -> void:
	if progress_lights.is_empty():
		return
	var progress: float = 0.0
	if recording and is_inside_tree() and has_node("AnomalyRecording"):
		var player_node: AudioStreamPlayer3D = %AnomalyRecording
		if player_node.stream != null:
			var length: float = player_node.stream.get_length()
			if length > 0.0:
				progress = clampf(player_node.get_playback_position() / length, 0.0, 1.0)
	var lit_count: int = int(round(progress * progress_lights.size()))
	for i in progress_lights.size():
		var light: MeshInstance3D = progress_lights[i]
		if light == null:
			continue
		var mat: Material = progress_light_on_material if i < lit_count else progress_light_off_material
		if mat != null:
			light.material_override = mat
