class_name LidarRenderer
extends Node3D

const HOLO_SHADER = preload("res://scripts/shaders/lidar_holo.gdshader")

enum ViewMode { SHIP_LOCKED, WORLD_LOCKED, RADAR_PING }

@export var view_mode: ViewMode = ViewMode.SHIP_LOCKED
@export var probe: ScanProbe = null
## Seconds the radar scan line takes to complete a full rotation.
@export var radar_period: float = 4.0
## Rays cast per frame along the radar's great-circle slice while in RADAR_PING.
@export var radar_rays_per_frame: int = 96
@export var radar_sweep: Node3D = null
@export var cardinal_ring: Node3D = null
@export var point_size: float = 0.003
@export var point_color: Color = Color(0.08, 0.95, 0.18, 1.0)
@export var asteroid_color: Color = Color(0.47, 0.433, 0.438, 1.0)
@export var ship_color: Color = Color(0.157, 0.541, 0.192, 1.0)
@export var anomaly_color: Color = Color(1.0, 0.18, 0.15, 1.0)
@export var emission_energy: float = 2.5
## Meters of scan space per meter of hologram radius. Smaller = more compressed.
@export var hologram_scale: float = 0.04
@export var max_points: int = 160000
## Seconds before a point fully fades to nothing.
@export var lifetime: float = 5.0
## Auto-scan cadence in seconds. 0 disables auto-scan.
@export var auto_scan_interval: float = 0.0
@export var ship_icon: MeshInstance3D = null
@export var ship_icon_brightness: float = 0.5

var on := false

const DEAD_CUSTOM := Color(-1.0e6, 0.0, 0.0, 0.0)

var _multi_mesh: MultiMesh
var _multi_mesh_instance: MultiMeshInstance3D
var _shader_material: ShaderMaterial
var _next_scan_time: float = 0.0
var _write_head: int = 0
var _anomaly_point_indices: Dictionary = {}
var _recolored_anomalies: Dictionary = {}
var _anchor: Node3D = null
var _base_basis: Basis = Basis.IDENTITY
var _icon_base_basis: Basis = Basis.IDENTITY
var _anomaly_multi_mesh: MultiMesh
var _anomaly_multi_mesh_instance: MultiMeshInstance3D
var _anomaly_slot_assignments: Dictionary = {}

const ANOMALY_DOTS_PER_NODE: int = 720
const MAX_TRACKED_ANOMALIES: int = 16


func _ready() -> void:
	_base_basis = transform.basis
	_anchor = get_node_or_null("Anchor") as Node3D
	if _anchor == null:
		_anchor = Node3D.new()
		_anchor.name = "Anchor"
		add_child(_anchor)
	_multi_mesh_instance = MultiMeshInstance3D.new()
	_anchor.add_child(_multi_mesh_instance)

	var sphere := SphereMesh.new()
	sphere.radius = point_size
	sphere.height = point_size * 2.0
	sphere.radial_segments = 4
	sphere.rings = 2

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = HOLO_SHADER
	_shader_material.set_shader_parameter("base_color", Vector3(point_color.r, point_color.g, point_color.b))
	_shader_material.set_shader_parameter("anomaly_color", Vector3(anomaly_color.r, anomaly_color.g, anomaly_color.b))
	_shader_material.set_shader_parameter("emission_energy", emission_energy)
	_shader_material.set_shader_parameter("lifetime", lifetime)
	_shader_material.set_shader_parameter("clip_min_local_y", 0.0)
	sphere.material = _shader_material

	_multi_mesh = MultiMesh.new()
	_multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_multi_mesh.use_custom_data = true
	_multi_mesh.mesh = sphere
	_multi_mesh.instance_count = max_points
	_multi_mesh_instance.multimesh = _multi_mesh

	var t_zero := Transform3D()
	for i in max_points:
		_multi_mesh.set_instance_transform(i, t_zero)
		_multi_mesh.set_instance_custom_data(i, DEAD_CUSTOM)

	if ship_icon != null:
		_icon_base_basis = ship_icon.transform.basis

	if ship_icon and ship_icon.material_override is ShaderMaterial:
		var icon_mat: ShaderMaterial = ship_icon.material_override
		icon_mat.set_shader_parameter("base_color", Vector3(ship_color.r, ship_color.g, ship_color.b))
		icon_mat.set_shader_parameter("emission_energy", emission_energy * ship_icon_brightness)

	_setup_anomaly_multi_mesh(sphere)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if _shader_material:
		_shader_material.set_shader_parameter("current_time", t)
		_shader_material.set_shader_parameter("lidar_origin_world", global_position)
		_shader_material.set_shader_parameter("clip_min_local_y", 0.0)
	if ship_icon and ship_icon.material_override is ShaderMaterial:
		(ship_icon.material_override as ShaderMaterial).set_shader_parameter("current_time", t)
	update_lidar()


func update_lidar() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_update_view_transform()
	_update_anomaly_clouds(t)
	_recolor_recorded_anomalies()

	if auto_scan_interval > 0.0 and probe != null:
		var now := Time.get_ticks_msec() / 1000.0
		if now >= _next_scan_time:
			trigger_scan()
			_next_scan_time = now + auto_scan_interval


func _sphere_radius_local() -> float:
	var sr: float = 50.0
	if probe != null:
		sr = probe.scan_range
	return sr * hologram_scale


func _setup_anomaly_multi_mesh(point_mesh: Mesh) -> void:
	_anomaly_multi_mesh = MultiMesh.new()
	_anomaly_multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_anomaly_multi_mesh.use_custom_data = true
	_anomaly_multi_mesh.mesh = point_mesh
	_anomaly_multi_mesh.instance_count = ANOMALY_DOTS_PER_NODE * MAX_TRACKED_ANOMALIES
	_anomaly_multi_mesh_instance = MultiMeshInstance3D.new()
	_anomaly_multi_mesh_instance.multimesh = _anomaly_multi_mesh
	_anchor.add_child(_anomaly_multi_mesh_instance)
	var t_zero := Transform3D()
	for i in _anomaly_multi_mesh.instance_count:
		_anomaly_multi_mesh.set_instance_transform(i, t_zero)
		_anomaly_multi_mesh.set_instance_custom_data(i, DEAD_CUSTOM)


func _assign_anomaly_slot(a: Node) -> int:
	if _anomaly_slot_assignments.has(a):
		return _anomaly_slot_assignments[a]
	var used := {}
	for s in _anomaly_slot_assignments.values():
		used[s] = true
	for i in MAX_TRACKED_ANOMALIES:
		var candidate: int = i * ANOMALY_DOTS_PER_NODE
		if not used.has(candidate):
			_anomaly_slot_assignments[a] = candidate
			return candidate
	return -1


func _clear_anomaly_slot(slot_start: int) -> void:
	for i in ANOMALY_DOTS_PER_NODE:
		_anomaly_multi_mesh.set_instance_custom_data(slot_start + i, DEAD_CUSTOM)


func _update_anomaly_clouds(now:float) -> void:
	if _anomaly_multi_mesh == null: return
	if probe == null:
		probe = get_tree().get_first_node_in_group("scan_probe") as ScanProbe
	if probe == null or probe.navigation == null:
		return
	var ship_pos: Vector3 = probe.global_position
	var sim_pos: Vector3 = probe.navigation.simulated_position
	var seen := {}

	for a in get_tree().get_nodes_in_group("anomaly"):
		if not is_instance_valid(a):
			continue
		var d: float = (a.global_position - ship_pos).length()
		if d > probe.scan_range:
			continue
		var slot_start: int = _assign_anomaly_slot(a)
		if slot_start < 0:
			continue
		seen[a] = true
		a.discovered = true
		var world_points: PackedVector3Array = a.get_lidar_points()
		var kind: float = 13.0 if a.recorded else 12.0
		var n: int = min(world_points.size(), ANOMALY_DOTS_PER_NODE)
		for i in n:
			var sim_coords: Vector3 = sim_pos + (world_points[i] - ship_pos)
			var local_pos: Vector3 = sim_coords * hologram_scale
			var xform := Transform3D()
			xform.origin = local_pos
			_anomaly_multi_mesh.set_instance_transform(slot_start + i, xform)
			_anomaly_multi_mesh.set_instance_custom_data(slot_start + i, Color(now, randf(), local_pos.y, kind))
		for i in range(n, ANOMALY_DOTS_PER_NODE):
			_anomaly_multi_mesh.set_instance_custom_data(slot_start + i, DEAD_CUSTOM)

	var to_remove := []
	for a in _anomaly_slot_assignments.keys():
		if not seen.has(a):
			to_remove.append(a)
	for a in to_remove:
		_clear_anomaly_slot(_anomaly_slot_assignments[a])
		_anomaly_slot_assignments.erase(a)


func _update_view_transform() -> void:
	if probe == null:
		probe = get_tree().get_first_node_in_group("scan_probe") as ScanProbe
	if probe == null or probe.navigation == null:
		return
	var heading: float = probe.navigation.heading
	var sim_pos: Vector3 = probe.navigation.simulated_position
	transform.basis = _base_basis
	if view_mode == ViewMode.WORLD_LOCKED:
		if _anchor != null:
			_anchor.transform.basis = Basis.IDENTITY
			_anchor.transform.origin = -sim_pos * hologram_scale
		if ship_icon != null:
			ship_icon.transform.basis = Basis(Vector3.UP, heading) * _icon_base_basis
	else:
		var rot := Basis(Vector3.UP, -heading)
		if _anchor != null:
			_anchor.transform.basis = rot
			_anchor.transform.origin = rot * (-sim_pos * hologram_scale)
		if ship_icon != null:
			ship_icon.transform.basis = _icon_base_basis
	if radar_sweep != null:
		radar_sweep.visible = false
	if cardinal_ring != null:
		if view_mode == ViewMode.WORLD_LOCKED:
			cardinal_ring.transform.basis = Basis.IDENTITY
		else:
			cardinal_ring.transform.basis = Basis(Vector3.UP, -heading)


func _recolor_recorded_anomalies() -> void:
	for _owner in _anomaly_point_indices.keys():
		if _recolored_anomalies.has(_owner):
			continue
		if not is_instance_valid(_owner):
			continue
		if not _owner.get("recorded"):
			continue
		var entries: Array = _anomaly_point_indices[_owner]
		for entry in entries:
			var idx: int = entry["idx"]
			var spawn_time: float = entry["spawn_time"]
			var data: Color = _multi_mesh.get_instance_custom_data(idx)
			if absf(data.r - spawn_time) < 0.001:
				var new_kind: float = 13.0 if data.a >= 9.5 else 3.0
				_multi_mesh.set_instance_custom_data(idx, Color(data.r, data.g, data.b, new_kind))
		_recolored_anomalies[_owner] = true


func trigger_scan() -> void:
	if probe == null:
		probe = get_tree().get_first_node_in_group("scan_probe") as ScanProbe
	if probe == null:
		push_warning("LidarRenderer: no ScanProbe found in tree")
		return
	var result: Dictionary = probe.scan()
	var hits: PackedVector3Array = result.get("hits", PackedVector3Array())
	var anomaly_hits_by_node: Dictionary = result.get("anomaly_hits_by_node", {})
	for anomaly_node in anomaly_hits_by_node.keys():
		display_points(anomaly_hits_by_node[anomaly_node], 2.0, anomaly_node)
	display_points(hits, 1.0)


func display_points(points: PackedVector3Array, hit_flag: float = 1.0, _owner: Node = null) -> void:
	var incoming: int = points.size()
	if incoming == 0:
		return

	var spawn_time := Time.get_ticks_msec() / 1000.0
	var owner_entries: Array = []
	if _owner != null:
		if not _anomaly_point_indices.has(_owner):
			_anomaly_point_indices[_owner] = []
		owner_entries = _anomaly_point_indices[_owner]

	for i in incoming:
		var idx: int = _write_head
		_write_head = (_write_head + 1) % max_points

		var local_pos := points[i] * hologram_scale
		var t := Transform3D()
		t.origin = local_pos
		_multi_mesh.set_instance_transform(idx, t)
		_multi_mesh.set_instance_custom_data(idx, Color(spawn_time, randf(), local_pos.y, hit_flag))
		if owner != null:
			owner_entries.append({"idx": idx, "spawn_time": spawn_time})

	if _owner != null and owner_entries.size() > 8000:
		var keep_start: int = owner_entries.size() - 4000
		_anomaly_point_indices[_owner] = owner_entries.slice(keep_start)


func clear() -> void:
	for i in max_points:
		_multi_mesh.set_instance_custom_data(i, DEAD_CUSTOM)
	_write_head = 0
