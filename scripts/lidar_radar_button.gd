class_name LidarRadarButton
extends StaticBody3D

@export var lidar: LidarRenderer = null
@export var button_mesh: MeshInstance3D = null
@export var off_color: Color = Color(0.35, 0.35, 0.4, 1.0)
@export var on_color: Color = Color(0.2, 1.0, 0.5, 1.0)
@export var emission_energy: float = 2.5
var on := false


func _ready() -> void:
	add_to_group("Interactable")
	_refresh_visual()


func _interact() -> void:
	if lidar == null: return
	var tween = create_tween()
	if on:
		tween.tween_property(self, "position:y", position.y + 0.03, 0.2)
	else:
		tween.tween_property(self, "position:y", position.y - 0.03, 0.2)
	on = not on
	lidar.toggle_radar_mode()
	_refresh_visual()


func _refresh_visual() -> void:
	if button_mesh == null or lidar == null:
		return
	var _on := lidar.view_mode == LidarRenderer.ViewMode.RADAR_PING
	var color := on_color if on else off_color
	var energy := emission_energy if _on else emission_energy * 0.25
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	button_mesh.material_override = mat
