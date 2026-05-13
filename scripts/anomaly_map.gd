class_name AnomalyMap
extends Node3D

## Half-size of the map panel along its local X/Z (meters).
@export var map_half_size: float = 0.1
## World radius (centered on origin) the map covers along X and Z.
@export var world_extent: float = 50.0
## Y offset above the panel surface where dots sit (meters).
@export var dot_lift: float = 0.006
@export var dot_mesh: Mesh = null
@export var dot_unscanned_material: Material = null
@export var dot_scanned_material: Material = null

var _entries: Array = []
var _by_anomaly: Dictionary = {}


func _process(_delta: float) -> void:
	for node in get_tree().get_nodes_in_group("anomaly"):
		var anom := node as Anomaly
		if anom == null or _by_anomaly.has(anom) or not anom.recorded:
			continue
		_chart(anom)


func _chart(anom: Anomaly) -> void:
	var dot := MeshInstance3D.new()
	dot.mesh = dot_mesh
	dot.material_override = dot_scanned_material
	dot.position = _world_to_map(anom.position)
	add_child(dot)
	_entries.append({"anomaly": anom, "dot": dot})
	_by_anomaly[anom] = true


func _world_to_map(world_xz: Vector3) -> Vector3:
	var denom: float = max(world_extent, 0.0001)
	var s: float = map_half_size / denom
	return Vector3(world_xz.x * s, dot_lift, world_xz.z * s)
