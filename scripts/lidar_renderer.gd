class_name LidarRenderer
extends Node3D

@export var probe: ScanProbe = null
@export var point_size: float = 0.003
@export var point_color: Color = Color(0.55, 1.0, 0.55)
@export var emission_energy: float = 2.5
## Meters of scan space per meter of hologram radius. Smaller = more compressed.
@export var hologram_scale: float = 0.04
@export var max_points: int = 40000
## Auto-scan cadence in seconds. 0 disables auto-scan.
@export var auto_scan_interval: float = 0.0

var _multi_mesh: MultiMesh
var _multi_mesh_instance: MultiMeshInstance3D
var _next_scan_time: float = 0.0


func _ready() -> void:
	_multi_mesh_instance = MultiMeshInstance3D.new()
	add_child(_multi_mesh_instance)

	var sphere := SphereMesh.new()
	sphere.radius = point_size
	sphere.height = point_size * 2.0
	sphere.radial_segments = 4
	sphere.rings = 2

	var mat := StandardMaterial3D.new()
	mat.albedo_color = point_color
	mat.emission_enabled = true
	mat.emission = point_color
	mat.emission_energy_multiplier = emission_energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = mat

	_multi_mesh = MultiMesh.new()
	_multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_multi_mesh.mesh = sphere
	_multi_mesh.instance_count = 0
	_multi_mesh_instance.multimesh = _multi_mesh


func _process(_delta: float) -> void:
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
	var hits := probe.scan()
	if hits.is_empty():
		push_warning("LidarRenderer: scan returned 0 hits — probe at %s, range %s" % [probe.global_position, probe.scan_range])
	display_points(hits)


func display_points(points: PackedVector3Array) -> void:
	var existing: int = _multi_mesh.instance_count
	var incoming: int = points.size()
	if incoming == 0:
		return

	if existing + incoming > max_points:
		var keep := max_points - incoming
		if keep < 0:
			keep = 0
		for i in keep:
			var src_idx := existing - keep + i
			_multi_mesh.set_instance_transform(i, _multi_mesh.get_instance_transform(src_idx))
		existing = keep

	var new_total := existing + incoming
	_multi_mesh.instance_count = new_total
	for i in incoming:
		var t := Transform3D()
		t.origin = points[i] * hologram_scale
		_multi_mesh.set_instance_transform(existing + i, t)


func clear() -> void:
	_multi_mesh.instance_count = 0
