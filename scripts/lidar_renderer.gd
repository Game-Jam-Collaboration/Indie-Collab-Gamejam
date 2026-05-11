class_name LidarRenderer
extends Node3D

const HOLO_SHADER = preload("res://scripts/shaders/lidar_holo.gdshader")

@export var probe: ScanProbe = null
@export var point_size: float = 0.003
@export var point_color: Color = Color(0.08, 0.95, 0.18)
@export var anomaly_color: Color = Color(1.0, 0.18, 0.15)
@export var emission_energy: float = 2.5
## Meters of scan space per meter of hologram radius. Smaller = more compressed.
@export var hologram_scale: float = 0.04
@export var max_points: int = 40000
## Seconds before a point fully fades to nothing.
@export var lifetime: float = 5.0
## Auto-scan cadence in seconds. 0 disables auto-scan.
@export var auto_scan_interval: float = 0.0
@export var ship_icon: MeshInstance3D = null
@export var ship_icon_brightness: float = 0.5

const DEAD_CUSTOM := Color(-1.0e6, 0.0, 0.0, 0.0)

var _multi_mesh: MultiMesh
var _multi_mesh_instance: MultiMeshInstance3D
var _shader_material: ShaderMaterial
var _next_scan_time: float = 0.0
var _write_head: int = 0


func _ready() -> void:
	_multi_mesh_instance = MultiMeshInstance3D.new()
	add_child(_multi_mesh_instance)

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

	if ship_icon and ship_icon.material_override is ShaderMaterial:
		var icon_mat: ShaderMaterial = ship_icon.material_override
		icon_mat.set_shader_parameter("base_color", Vector3(point_color.r, point_color.g, point_color.b))
		icon_mat.set_shader_parameter("emission_energy", emission_energy * ship_icon_brightness)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if _shader_material:
		_shader_material.set_shader_parameter("current_time", t)
		_shader_material.set_shader_parameter("lidar_origin_world", global_position)
	if ship_icon and ship_icon.material_override is ShaderMaterial:
		(ship_icon.material_override as ShaderMaterial).set_shader_parameter("current_time", t)

	if auto_scan_interval <= 0.0 or probe == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now >= _next_scan_time:
		trigger_scan()
		_next_scan_time = now + auto_scan_interval


func trigger_scan() -> void:
	if probe == null:
		probe = get_tree().get_first_node_in_group("scan_probe") as ScanProbe
	if probe == null:
		push_warning("LidarRenderer: no ScanProbe found in tree")
		return
	var result: Dictionary = probe.scan()
	var hits: PackedVector3Array = result.get("hits", PackedVector3Array())
	var misses: PackedVector3Array = result.get("misses", PackedVector3Array())
	var anomaly_hits: PackedVector3Array = result.get("anomaly_hits", PackedVector3Array())
	display_points(hits, 1.0)
	display_points(misses, 0.0)
	display_points(anomaly_hits, 2.0)


func display_points(points: PackedVector3Array, hit_flag: float = 1.0) -> void:
	var incoming: int = points.size()
	if incoming == 0:
		return

	var spawn_time := Time.get_ticks_msec() / 1000.0
	for i in incoming:
		var idx: int = _write_head
		_write_head = (_write_head + 1) % max_points

		var local_pos := points[i] * hologram_scale
		var t := Transform3D()
		t.origin = local_pos
		_multi_mesh.set_instance_transform(idx, t)
		_multi_mesh.set_instance_custom_data(idx, Color(spawn_time, randf(), local_pos.y, hit_flag))


func clear() -> void:
	for i in max_points:
		_multi_mesh.set_instance_custom_data(i, DEAD_CUSTOM)
	_write_head = 0
