extends Node2D

@export var button_input_variation : Array = []

func _ready() -> void:
	
	#Connecting signals for buttons and mouse inputs.
	
	#Start
	get_node("Control/Button").mouse_entered.connect(_mouse_entered.bind(""))
	get_node("Control/Button").mouse_exited.connect(_mouse_exited.bind(""))
	get_node("Control/Button").pressed.connect(_mouse_pressed.bind(0))
	
	#Credits
	get_node("Control/Button2").mouse_entered.connect(_mouse_entered.bind(2))
	get_node("Control/Button2").mouse_exited.connect(_mouse_exited.bind(2))
	get_node("Control/Button2").pressed.connect(_mouse_pressed.bind(1))
	
	#Exit
	get_node("Control/Button3").mouse_entered.connect(_mouse_entered.bind(3))
	get_node("Control/Button3").mouse_exited.connect(_mouse_exited.bind(3))
	get_node("Control/Button3").pressed.connect(_mouse_pressed.bind(2))
	
	


func _mouse_entered(button_index):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(get_node("Control/Button"+str(button_index)),"scale",Vector2(1.1,1.1),0.1)

func _mouse_exited(button_index):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(get_node("Control/Button"+str(button_index)),"scale",Vector2(1,1),0.1)


func _mouse_pressed(button_index):
	if button_index == 0:
		_execute_input_command(button_index)
	elif button_index == 1:
		_execute_input_command(button_index)
	elif button_index == 2:
		_execute_input_command(button_index)
	

func _execute_input_command(button_index):
	if button_input_variation[button_index] == "" or button_input_variation[button_index] == null:
		print("It's button input is empty or null")
	else:
		if button_input_variation[button_index].substr(0,6) == "res://":
			get_tree().change_scene_to_file(button_input_variation[button_index])
		elif button_input_variation[button_index].substr(0,6) == "Quit":
			get_tree().quit()
		
