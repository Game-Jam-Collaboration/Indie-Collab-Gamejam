class_name Anomaly
extends Node3D

@export var anomaly_id:String = "ANOM-01"
@export var chase_speed: float = 16
@export var chase_stop_distance: float = 1.0
@export var chase_ramp_seconds: float = 1.5

const CHASE_RUMBLE_STREAM := preload("res://assets/sounds/CJ26_DarkAmbience-demo.mp3")
const RUMBLE_FAR_DB: float = -45.0
const RUMBLE_NEAR_DB: float = -6.0
const RUMBLE_FAR_DIST: float = 80.0
const RUMBLE_NEAR_DIST: float = 4.0
const RUMBLE_RAMP_PER_SEC: float = 22.0

const SPHERE_RADIUS: float = 4.5
const SPHERE_POINTS: int = 60
const RING_RADIUS: float = 10.0
const RING_ANGLE_POINTS: int = 26
const RING_TUBE_POINTS: int = 8
const RING_TUBE_RADIUS: float = 1.6
const SPIN_SPEED_MIN: float = 0.15
const SPIN_SPEED_MAX: float = 0.5
const RING_SPEED_MIN: float = 0.8
const RING_SPEED_MAX: float = 1.6

var recorded: bool = false
var being_recorded: bool = false
var discovered: bool = false
var chasing: bool = false

var _sphere_template: PackedVector3Array = PackedVector3Array()
var _base_orientation: Basis = Basis.IDENTITY
var _spin_axis: Vector3 = Vector3.UP
var _spin_speed: float = 0.3
var _ring_speeds: Array = [1.0, 1.0, 1.0]
var _end_game_triggered: bool = false
var _chase_elapsed: float = 0.0
var _rumble_player: AudioStreamPlayer = null


func _ready() -> void:
	add_to_group("anomaly")
	_sphere_template = _fibonacci_sphere(SPHERE_RADIUS, SPHERE_POINTS)
	_randomize_motion()
	_rumble_player = AudioStreamPlayer.new()
	_rumble_player.stream = CHASE_RUMBLE_STREAM
	_rumble_player.volume_db = -80.0
	_rumble_player.bus = &"Master"
	add_child(_rumble_player)


func _physics_process(delta: float) -> void:
	if not chasing:
		_chase_elapsed = 0.0
		_fade_out_rumble(delta)
		return
	if being_recorded:
		return
	var nav := get_tree().get_first_node_in_group("ship_navigation") as ShipNavigation
	if nav == null:
		return
	# Smoothstep ramp-up so the anomaly eases into motion instead of snapping to full speed.
	_chase_elapsed += delta
	var t: float = clampf(_chase_elapsed / max(chase_ramp_seconds, 0.0001), 0.0, 1.0)
	var factor: float = t * t * (3.0 - 2.0 * t)
	var to_target: Vector3 = nav.simulated_position - position
	var dist: float = to_target.length()
	_update_chase_rumble(dist, delta)
	if dist > chase_stop_distance:
		position += to_target.normalized() * chase_speed * factor * delta
	elif not _end_game_triggered:
		_end_game_triggered = true
		_trigger_end_game()


func _update_chase_rumble(dist: float, delta: float) -> void:
	if _rumble_player == null:
		return
	if not _rumble_player.playing:
		_rumble_player.play()
	var span: float = max(RUMBLE_FAR_DIST - RUMBLE_NEAR_DIST, 0.0001)
	var t: float = clampf((RUMBLE_FAR_DIST - dist) / span, 0.0, 1.0)
	var target_db: float = lerpf(RUMBLE_FAR_DB, RUMBLE_NEAR_DB, t)
	_rumble_player.volume_db = move_toward(_rumble_player.volume_db, target_db, RUMBLE_RAMP_PER_SEC * delta)


func _fade_out_rumble(delta: float) -> void:
	if _rumble_player == null or not _rumble_player.playing:
		return
	_rumble_player.volume_db = move_toward(_rumble_player.volume_db, -80.0, RUMBLE_RAMP_PER_SEC * delta)
	if _rumble_player.volume_db <= -79.5:
		_rumble_player.stop()


func _trigger_end_game() -> void:
	var rb: Node = get_tree().get_first_node_in_group("record_button")
	if rb == null:
		return
	if rb.recording:
		_end_game_triggered = false
		return
	var p = rb.get("player")
	if p != null and p.has_method("end_game"):
		p.end_game()


func get_lidar_points() -> PackedVector3Array:
	var t: float = Time.get_ticks_msec() / 1000.0
	var spin: Basis = Basis(_spin_axis, t * _spin_speed)
	var obj_basis: Basis = spin * _base_orientation
	var xform: Transform3D = global_transform
	var pts := PackedVector3Array()

	for p in _sphere_template:
		pts.append(xform * (obj_basis * p))

	_append_animated_ring(pts, xform, obj_basis, Vector3(1, 0, 0), Vector3(0, 1, 0), t * _ring_speeds[0])
	_append_animated_ring(pts, xform, obj_basis, Vector3(1, 0, 0), Vector3(0, 0, 1), t * _ring_speeds[1])
	_append_animated_ring(pts, xform, obj_basis, Vector3(0, 1, 0), Vector3(0, 0, 1), t * _ring_speeds[2])

	return pts


func _append_animated_ring(pts: PackedVector3Array, xform: Transform3D, obj_basis: Basis, u: Vector3, v: Vector3, phase: float) -> void:
	var w: Vector3 = u.cross(v).normalized()
	for i in RING_ANGLE_POINTS:
		var theta: float = TAU * float(i) / float(RING_ANGLE_POINTS) + phase
		var radial: Vector3 = cos(theta) * u + sin(theta) * v
		var center: Vector3 = RING_RADIUS * radial
		for j in RING_TUBE_POINTS:
			var phi: float = TAU * float(j) / float(RING_TUBE_POINTS)
			var offset: Vector3 = RING_TUBE_RADIUS * (cos(phi) * radial + sin(phi) * w)
			pts.append(xform * (obj_basis * (center + offset)))


func _randomize_motion() -> void:
	_base_orientation = Basis().rotated(Vector3.RIGHT, randf() * TAU).rotated(Vector3.UP, randf() * TAU).rotated(Vector3.FORWARD, randf() * TAU)
	_spin_axis = _random_unit_vector()
	_spin_speed = randf_range(SPIN_SPEED_MIN, SPIN_SPEED_MAX)
	for i in 3:
		var direction: float = 1.0 if randf() < 0.5 else -1.0
		_ring_speeds[i] = direction * randf_range(RING_SPEED_MIN, RING_SPEED_MAX)


func _random_unit_vector() -> Vector3:
	var z: float = randf_range(-1.0, 1.0)
	var phi: float = randf() * TAU
	var r: float = sqrt(max(0.0, 1.0 - z * z))
	return Vector3(cos(phi) * r, z, sin(phi) * r)


func _fibonacci_sphere(radius: float, n: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var golden: float = PI * (sqrt(5.0) - 1.0)
	for i in n:
		var y: float = 1.0 - 2.0 * float(i) / float(max(1, n - 1))
		var r: float = sqrt(max(0.0, 1.0 - y * y))
		var theta: float = golden * float(i)
		pts.append(Vector3(cos(theta) * r * radius, y * radius, sin(theta) * r * radius))
	return pts
