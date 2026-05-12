extends StaticBody3D

var lever_anim = load("res://assets/animations/heater_lever.res")

var offline := false

func _interact() -> void:
	if offline:
		offline = false
		%AnimationPlayer.play_backwards("heater_lever")
	else:
		offline = true
		%AnimationPlayer.play("heater_lever")
