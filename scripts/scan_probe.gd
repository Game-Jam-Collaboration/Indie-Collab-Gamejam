class_name ScanProbe
extends Node3D

@export var navigation: ShipNavigation = null
@export var ray_count: int = 20000
@export var scan_range: float = 50.0


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
	var sim_pos: Vector3 = Vector3.ZERO
	if navigation: sim_pos = navigation.simulated_position

	for i in ray_count:
		var angle := TAU * float(i) / float(ray_count)

		# Flat circle on X/Y plane. No Z.
		var dir := Vector3(cos(angle), sin(angle), 0.0).normalized()

		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * scan_range)
		query.hit_from_inside = true

		var result := space_state.intersect_ray(query)
		if result and result.has("position"):
			var hit_pos: Vector3 = result["position"]
			var hit_local: Vector3 = sim_pos + (hit_pos - origin)
			var collider = result.get("collider")

			if collider == null or not collider.is_in_group("anomaly"):
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
			if collider == null or not collider.is_in_group("anomaly"):
				hits.append(hit_local)
		else:
			misses.append(sim_pos + dir * scan_range)

	return {"hits": hits, "misses": misses, "anomaly_hits_by_node": anomaly_hits_by_node}
