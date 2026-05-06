extends Area3D

@export var environment_light:Light3D = null
@export var emissive_object:MeshInstance3D
@export var status_panel: AssemblyStatusPanel = null
@export var slot_index: int = 0
@export var can_remove_fuse: bool = false

var _original_light_color: Color
var _original_emission_material: Material


func _ready() -> void:
	if environment_light:
		_original_light_color = environment_light.light_color
	if emissive_object and emissive_object.mesh:
		_original_emission_material = emissive_object.mesh.surface_get_material(0)


func assemble() -> void:
	if status_panel:
		status_panel.mark_complete(slot_index)
	if environment_light:
		environment_light.light_color = Color.CORNSILK
	if emissive_object:
		var new_material:StandardMaterial3D = emissive_object.mesh.surface_get_material(0).duplicate()
		new_material.emission = Color.WHITE_SMOKE
		new_material.emission_energy_multiplier = 3
		emissive_object.mesh.surface_set_material(0, new_material)


func can_remove() -> bool:
	return can_remove_fuse and _has_assembled_fuse()


func _has_assembled_fuse() -> bool:
	var ap := get_node_or_null("AssemblyPoint")
	return ap != null and ap.get_child_count() > 0


func release_assembled() -> CollisionObject3D:
	var ap := get_node_or_null("AssemblyPoint")
	if ap == null or ap.get_child_count() == 0:
		return null
	var fuse := ap.get_child(0) as CollisionObject3D
	if fuse == null:
		return null
	if status_panel:
		status_panel.mark_pending(slot_index)
	if environment_light:
		environment_light.light_color = _original_light_color
	if emissive_object and _original_emission_material:
		emissive_object.mesh.surface_set_material(0, _original_emission_material)
	return fuse
