class_name ScanProbe
extends Node3D

@export var navigation: ShipNavigation = null
@export var ray_count: int = 120000
@export var scan_range: float = 50.0
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


func scan() -> Dictionary:
	_resolve_navigation()
	var hits := PackedVector3Array()
	var misses := PackedVector3Array()
	var anomaly_hits_by_node: Dictionary = {}
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return {"hits": hits, "misses": misses, "anomaly_hits_by_node": anomaly_hits_by_node}

	var origin := global_position
	var phi := PI * (sqrt(5.0) - 1.0)
	var sim_pos: Vector3 = Vector3.ZERO
	if navigation:
		sim_pos = navigation.simulated_position

	for i in ray_count:
		var t := float(i) / float(max(1, ray_count - 1))
		var y := 1.0 - 2.0 * t
		var r := sqrt(max(0.0, 1.0 - y * y))
		var theta := phi * float(i)
		var dir := Vector3(cos(theta) * r, y, sin(theta) * r)
		dir = dir.rotated(Vector3.UP, randf_range(-jitter_radians, jitter_radians))
		dir = dir.rotated(Vector3.RIGHT, randf_range(-jitter_radians, jitter_radians))

		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * scan_range)
		query.hit_from_inside = true
		var result := space_state.intersect_ray(query)
		if result and result.has("position"):
			var hit_pos: Vector3 = result["position"]
			var hit_local: Vector3 = sim_pos + (hit_pos - origin)
			var collider = result.get("collider")
			if collider != null and collider.is_in_group("anomaly") and not collider.recorded:
				if not anomaly_hits_by_node.has(collider):
					anomaly_hits_by_node[collider] = PackedVector3Array()
				anomaly_hits_by_node[collider].append(hit_local)
				collider.discovered = true
			else:
				hits.append(hit_local)
		else:
			misses.append(sim_pos + dir * scan_range)

	return {"hits": hits, "misses": misses, "anomaly_hits_by_node": anomaly_hits_by_node}


func scan_directions(directions: PackedVector3Array) -> Dictionary:
	_resolve_navigation()
	var hits := PackedVector3Array()
	var misses := PackedVector3Array()
	var anomaly_hits_by_node: Dictionary = {}
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return {"hits": hits, "misses": misses, "anomaly_hits_by_node": anomaly_hits_by_node}

	var origin := global_position
	var sim_pos: Vector3 = Vector3.ZERO
	if navigation:
		sim_pos = navigation.simulated_position

	for dir in directions:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * scan_range)
		query.hit_from_inside = true
		var result := space_state.intersect_ray(query)
		if result and result.has("position"):
			var hit_pos: Vector3 = result["position"]
			var hit_local: Vector3 = sim_pos + (hit_pos - origin)
			var collider = result.get("collider")
			if collider != null and collider.is_in_group("anomaly") and not collider.recorded:
				if not anomaly_hits_by_node.has(collider):
					anomaly_hits_by_node[collider] = PackedVector3Array()
				anomaly_hits_by_node[collider].append(hit_local)
				collider.discovered = true
			else:
				hits.append(hit_local)
		else:
			misses.append(sim_pos + dir * scan_range)

	return {"hits": hits, "misses": misses, "anomaly_hits_by_node": anomaly_hits_by_node}
