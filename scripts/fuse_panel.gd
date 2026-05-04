extends Area3D

@export var environment_light:Light3D = null


func assemble() -> void:
	if environment_light:
		environment_light.light_color = Color.DARK_GREEN
