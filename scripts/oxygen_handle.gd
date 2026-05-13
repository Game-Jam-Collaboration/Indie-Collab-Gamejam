extends StaticBody3D

@onready var oxygen:Oxygen = get_parent()
var tween:Tween = null


func _interact() -> void:
	if oxygen.online: return
	if tween != null: return
	tween = create_tween()
	tween.tween_method(
		func(v:float): %Lever.set_blend_shape_value(0, v),
		0.0,
		1.0,
		.1
	)
	oxygen.pump()
	await tween.finished
	tween = create_tween()
	tween.tween_method(
		func(v:float): %Lever.set_blend_shape_value(0, v),
		1.0,
		0.0,
		.1
	)
	await tween.finished
	tween = null
	
