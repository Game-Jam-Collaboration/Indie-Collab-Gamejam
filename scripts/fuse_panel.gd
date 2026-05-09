extends Area3D

@export var environment_light:Light3D = null
@export var emissive_object:MeshInstance3D
@export var emissive_material_idx:int = 0
@export var status_panel: AssemblyStatusPanel = null
@export var slot_index: int = 0
@export var can_remove_fuse: bool = false
@export var fuse:RigidBody3D = null

var online := false

var offline_light_color:Color = Color.FIREBRICK
var online_light_color:Color = Color.FOREST_GREEN

var offline_emissive:StandardMaterial3D = load("res://assets/materials/offline_emissive.tres")
var online_emissive:StandardMaterial3D = load("res://assets/materials/online_emissive.tres")


func assemble() -> void:
	if status_panel:
		status_panel.mark_complete(slot_index)
	online = true
	_change_lighting()


func disassemble() -> void:
	if status_panel:
		status_panel.mark_pending(slot_index)
	online = false
	_change_lighting()
	fuse.freeze = false
	fuse.apply_central_impulse(Vector3(-2, 0, 0))
	fuse.apply_torque_impulse(Vector3(randf_range(-.5, .5), 0,0))


func _change_lighting() -> void:
	if !online:
		if environment_light:
			environment_light.light_color = offline_light_color
		if emissive_object:
			emissive_object.mesh.surface_set_material(emissive_material_idx, offline_emissive)
	else:
		if environment_light:
			environment_light.light_color = online_light_color
		if emissive_object:
			emissive_object.mesh.surface_set_material(emissive_material_idx, online_emissive)


func can_remove() -> bool:
	return can_remove_fuse and _has_assembled_fuse()


func _has_assembled_fuse() -> bool:
	var ap := get_node_or_null("AssemblyPoint")
	return ap != null and ap.get_child_count() > 0


func release_assembled() -> CollisionObject3D:
	var ap := get_node_or_null("AssemblyPoint")
	if ap == null or ap.get_child_count() == 0:
		return null
	var _fuse := ap.get_child(0) as CollisionObject3D
	if _fuse == null:
		return null
	if status_panel:
		status_panel.mark_pending(slot_index)
	_change_lighting()
	return _fuse
