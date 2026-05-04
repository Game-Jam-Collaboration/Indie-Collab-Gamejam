extends Node3D

@onready var player:Player = $Player


func _ready() -> void:
	PauseMenu.visible = false
