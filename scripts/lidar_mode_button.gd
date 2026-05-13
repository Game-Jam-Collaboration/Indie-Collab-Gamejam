class_name LidarModeButton
extends StaticBody3D

@export var lidar: LidarRenderer = null
@export var button_mesh: MeshInstance3D = null
@export var ship_locked_color: Color = Color(0.25, 0.6, 1.0, 1.0)
@export var world_locked_color: Color = Color(1.0, 0.55, 0.2, 1.0)
@export var emission_energy: float = 2.5


func _ready() -> void:
	add_to_group("Interactable")
	_refresh_visual()


func _interact() -> void:
	if lidar == null:
		return
	lidar.toggle_view_mode()
	_refresh_visual()


func _refresh_visual() -> void:
	if button_mesh == null or lidar == null:
		return
	var color := ship_locked_color
	if lidar.view_mode == LidarRenderer.ViewMode.WORLD_LOCKED:
		color = world_locked_color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = emission_energy
	button_mesh.material_override = mat
