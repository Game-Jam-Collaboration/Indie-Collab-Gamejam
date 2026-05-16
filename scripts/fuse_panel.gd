class_name FusePanel
extends Area3D

@export var environment_light:Light3D = null
@export var emissive_object:MeshInstance3D
@export var emissive_material_idx:int = 0
@export var status_panel: AssemblyStatusPanel = null
@export var slot_index: int = 0
@export var can_remove_fuse: bool = false
@export var fuse:RigidBody3D = null
@export var audio:AudioStreamPlayer3D = null
@export var holodeck:Node3D = null
@export var heater:Node3D = null

var online := false

var offline_light_color:Color = Color.FIREBRICK
var online_light_color:Color = Color.FOREST_GREEN

var offline_emissive:StandardMaterial3D = load("res://assets/materials/offline_emissive.tres")
var online_emissive:StandardMaterial3D = load("res://assets/materials/online_emissive.tres")


func assemble() -> void:
	if status_panel:
		status_panel.mark_complete(slot_index)
	print("power on")
	online = true
	_change_lighting()
	if audio:
		audio.play()
	if heater:
		heater.online = true
	if holodeck:
		holodeck.get_node("%Powered").visible = true
		holodeck.get_node("%RadarSound").play()
		holodeck.get_node("%LidarRenderer").update_lidar()


func disassemble() -> void:
	if !online: return
	_power_off()
	if fuse:
		fuse.freeze = false
		fuse.apply_central_impulse(Vector3(-2, 0, 0))
		fuse.apply_torque_impulse(Vector3(randf_range(-.5, .5), 0, 0))
		fuse.add_to_group("Pickupable")


func _power_off() -> void:
	if !online: return
	if status_panel:
		status_panel.mark_pending(slot_index)
	print("power off")
	online = false
	_change_lighting()
	if heater:
		heater.online = false
	if holodeck:
		holodeck.get_node("%Powered").visible = false
		holodeck.get_node("%RadarSound").stop()


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
