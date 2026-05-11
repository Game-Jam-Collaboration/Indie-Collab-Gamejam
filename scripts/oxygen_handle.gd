extends StaticBody3D

var tween:Tween = null


func _interact() -> void:
	if tween != null: return
	tween = create_tween()
	tween.tween_method(
		func(v:float): %Lever.set_blend_shape_value(0, v),
		0.0,
		1.0,
		.35
	)
	await tween.finished
	tween = create_tween()
	tween.tween_method(
		func(v:float): %Lever.set_blend_shape_value(0, v),
		1.0,
		0.0,
		.35
	)
	await tween.finished
	tween = null
	
