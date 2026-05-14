class_name Ship
extends Node3D

@export var player:Player = null
@export var fuse_panel:FusePanel = null
@export var heater_lever:HeaterLever = null
@export var oxygen:Oxygen = null
@export var holodeck:Node3D
@export var record_button:RecordButton = null

var count = 0
var attacks = 0



func _attack() -> void:
	if record_button.anomalies_record < 3: return
	if !fuse_panel.online or !heater_lever.heater.online and !oxygen.online: return
	count += 1
	var entity_attack:bool = (randi_range(0, 100) > 85)
	if entity_attack:
		%EntityAttack.play()
		await get_tree().create_timer(1.2).timeout
		heater_lever._interact(true)
		oxygen.release_pressure()
		holodeck.get_node("%Powered").visible = false
		fuse_panel.disassemble()
		player._attack_camera_shake()
		attacks += 1
		print("Entity has attacked: %d times out of %d rolls!" % [attacks, count])
