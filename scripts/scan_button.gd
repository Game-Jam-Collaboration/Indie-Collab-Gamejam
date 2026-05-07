class_name ScanButton
extends StaticBody3D

@export var lidar: LidarRenderer = null
@export var scan_duration: float = 2.0
@export var idle_color: Color = Color(0.25, 0.7, 0.35, 1)
@export var scanning_color: Color = Color(0.7, 1.0, 0.55, 1)
@export var button_mesh: MeshInstance3D = null

var _is_scanning: bool = false
var _scan_end_time: float = 0.0


func _ready() -> void:
	add_to_group("Interactable")
	_apply_color(idle_color, 1.5)


func _interact() -> void:
	if _is_scanning or lidar == null:
		return
	_is_scanning = true
	_scan_end_time = Time.get_ticks_msec() / 1000.0 + scan_duration
	_apply_color(scanning_color, 4.0)


func _process(_delta: float) -> void:
	if not _is_scanning:
		return
	if Time.get_ticks_msec() / 1000.0 >= _scan_end_time:
		_is_scanning = false
		lidar.trigger_scan()
		_apply_color(idle_color, 1.5)


func _apply_color(color: Color, energy: float) -> void:
	if button_mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	button_mesh.material_override = mat
