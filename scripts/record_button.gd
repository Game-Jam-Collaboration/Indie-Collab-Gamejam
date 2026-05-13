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

var _current_anomaly: Anomaly = null
var _cover_rest_basis: Basis = Basis.IDENTITY
var _cover_open: float = 0.0
var _flash_timer: float = 0.0
var _light_on: bool = false
var recording := false


func _ready() -> void:
	if cover:
		_cover_rest_basis = cover.transform.basis
	_set_light(false)


func _resolve_navigation() -> void:
	if navigation == null:
		navigation = get_tree().get_first_node_in_group("ship_navigation") as ShipNavigation


func _process(delta: float) -> void:
	_resolve_navigation()
	_update_target()
	var want_open := _current_anomaly != null
	_cover_open = move_toward(_cover_open, 1.0 if want_open else 0.0, cover_anim_speed * delta)
	_apply_cover_rotation()
	if recording:
		_update_flash(delta)
	else:
		_set_light(want_open)


func _interact() -> void:
	if _current_anomaly == null: return
	var anomaly = _current_anomaly
	_current_anomaly = null
	anomaly.recorded = true
	await get_tree().process_frame
	print("[ANOMALY] %s scanned and recorded" % anomaly.anomaly_id)
	recording = true
	await anomaly.record()
	recording = false


func _update_target() -> void:
	_current_anomaly = null
	if navigation == null: return
	var closest := detection_range
	for node in get_tree().get_nodes_in_group("anomaly"):
		var anom := node as Anomaly
		if anom == null or anom.recorded: continue
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
