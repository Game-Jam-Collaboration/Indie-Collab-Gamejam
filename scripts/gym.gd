extends Node3D

@onready var player:Player = $Player


func _ready() -> void:
	PauseMenu.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_E:
				if !get_tree().debug_collisions_hint:
					get_tree().debug_collisions_hint = true
				else:
					get_tree().debug_collisions_hint = false
				get_tree().reload_current_scene()
			elif event.keycode == KEY_T:
				%ThirdPersonCamera.make_current()
				player.camera_enabled = false
