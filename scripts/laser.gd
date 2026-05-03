@tool
extends Node3D


@export_tool_button("Grow Laser") var grow_laser = _grow
@export_tool_button("Reset Laser") var reset_laser = _reset


func _grow() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_method(_growth_function.bind(tween), 0.0, 1.0, 1)
	tween.tween_property(%RayCast, "position:y", 10, 1)


func _growth_function(value, tween) -> void:
	%RayCast.force_raycast_update()
	print(%RayCast.is_colliding())
	if !%RayCast.is_colliding():
		%Mesh.set_blend_shape_value(0, value)
		%RayCast.position.y += value * 10
	else:
		tween.kill()
	


func _reset() -> void:
	%RayCast.position.y = -0.1
	%Mesh.set_blend_shape_value(0, 0.0)
