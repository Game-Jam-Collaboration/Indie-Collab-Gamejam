class_name ScanProbe
extends Node3D

@export var navigation: ShipNavigation = null
@export var ray_count: int = 8000
@export var scan_range: float = 30.0
@export var jitter_radians: float = 0.025


func _ready() -> void:
	add_to_group("scan_probe")


func _resolve_navigation() -> void:
	if navigation == null:
		navigation = get_tree().get_first_node_in_group("ship_navigation") as ShipNavigation


func _process(_delta: float) -> void:
	_resolve_navigation()
	if navigation == null:
		return
	position = navigation.simulated_position


func scan() -> PackedVector3Array:
	_resolve_navigation()
	var hits := PackedVector3Array()
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return hits

	var origin := global_position
	var phi := PI * (sqrt(5.0) - 1.0)
	var heading := 0.0
	if navigation:
		heading = navigation.heading
	var basis := Basis(Vector3.UP, heading)

	for i in ray_count:
		var t := float(i) / float(max(1, ray_count - 1))
		var y := 1.0 - 2.0 * t
		var r := sqrt(max(0.0, 1.0 - y * y))
		var theta := phi * float(i)
		var dir := Vector3(cos(theta) * r, y, sin(theta) * r)
		dir = dir.rotated(Vector3.UP, randf_range(-jitter_radians, jitter_radians))
		dir = dir.rotated(Vector3.RIGHT, randf_range(-jitter_radians, jitter_radians))

		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * scan_range)
		var result := space_state.intersect_ray(query)
		if result and result.has("position"):
			var local: Vector3 = result["position"] - origin
			hits.append(basis.transposed() * local)

	return hits
