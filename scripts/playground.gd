extends Node3D


func _ready() -> void:
	if Engine.is_editor_hint():
		PhysicsServer3D.set_active(true)
