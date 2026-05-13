extends Node3D

@export var player:Player = null
@export var fuse_panel:FusePanel = null
@export var heater_lever:HeaterLever = null

var count = 0
var attacks = 0



func _attack() -> void:
	if !fuse_panel.online or !heater_lever.heater.online: return
	count += 1
	var entity_attack:bool = (randi_range(0, 100) > 50)
	if entity_attack:
		%EntityAttack.play()
		await get_tree().create_timer(1.2).timeout
		heater_lever._interact(true)
		fuse_panel.disassemble()
		player._attack_camera_shake()
		attacks += 1
		print("Entity has attacked: %d times out of %d rolls!" % [attacks, count])
