@tool
extends Node3D


@export_tool_button("Grow Laser") var grow_laser = _grow
@export_tool_button("Reset Laser") var reset_laser = _reset
## In seconds. This is not time to object, it's a rough rate of travel.
@export var growth_speed:float = 1.0


func _grow() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_method(_growth_function.bind(tween), 0.0, 1.0, growth_speed)
	tween.tween_property(%Body, "position:y", 10, 1)


func _growth_function(value:float, tween:Tween) -> void:
	visible = true
	if !%Body.has_overlapping_bodies():
		%Mesh.set_blend_shape_value(0, value)
		%Body.position.y += value * 10
	else:
		tween.kill()
		%Cover.visible = true
		# pull back just a tid so that we go z-fight with whatever we collided with
		#%Mesh.set_blend_shape_value(0, value - 0.015)


func _reset() -> void:
	visible = false
	%Body.position.y = 0
	%Mesh.set_blend_shape_value(0, 0.0)
