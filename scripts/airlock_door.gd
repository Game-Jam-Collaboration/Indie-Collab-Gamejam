extends Node3D


func _open() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(%LeftSide, "position:x", %LeftSide.position.x - 1.6, .5)
	tween.tween_property(%RightSide, "position:x", %RightSide.position.x + 1.6, .5)
