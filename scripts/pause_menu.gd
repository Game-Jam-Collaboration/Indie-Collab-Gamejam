extends PanelContainer

const VOLUME_LEVELS: Array = [1.0, 0.75, 0.5, 0.25, 0.0]

@export var button_input_variation : Array = []

@export var script_type : String
var current_scene = ""
var _volume_index: int = 0

var focused:bool:
	get:
		return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	
	if script_type == "Pause":
		if get_tree().current_scene.name == "MainMenu":
			hide()
	
	#Connecting signals for buttons and mouse inputs.
	
	#Start or Continue in Pause
	get_node("MarginContainer/Control/Button").mouse_entered.connect(_mouse_entered.bind(""))
	get_node("MarginContainer/Control/Button").mouse_exited.connect(_mouse_exited.bind(""))
	get_node("MarginContainer/Control/Button").pressed.connect(_mouse_pressed.bind(0))
	
	#Exit
	get_node("MarginContainer/Control/Button3").mouse_entered.connect(_mouse_entered.bind(3))
	get_node("MarginContainer/Control/Button3").mouse_exited.connect(_mouse_exited.bind(3))
	get_node("MarginContainer/Control/Button3").pressed.connect(_mouse_pressed.bind(2))
	
	


func _mouse_entered(button_index):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(get_node("MarginContainer/Control/Button"+str(button_index)),"scale",Vector2(1.1,1.1),0.1)
	

func _mouse_exited(button_index):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(get_node("MarginContainer/Control/Button"+str(button_index)),"scale",Vector2(1,1),0.1)
	


func _mouse_pressed(button_index):
	if button_index == 0:
		_execute_input_command(button_index)
	elif button_index == 1:
		_execute_input_command(button_index)
	elif button_index == 2:
		_execute_input_command(button_index)
	

##Keyboard inputs. Such as escape to show and hide its PauseMenu.
func _unhandled_input(event):
	if script_type == "Pause":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_QUOTELEFT:
				_cycle_volume()
		#print(current_scene)
		if current_scene == "ship":
			if event is InputEventKey and event.pressed:
				if event.keycode == KEY_ESCAPE:
					visible = !focused


func _cycle_volume() -> void:
	_volume_index = (_volume_index + 1) % VOLUME_LEVELS.size()
	var v: float = VOLUME_LEVELS[_volume_index]
	var bus_idx: int = AudioServer.get_bus_index("Master")
	if bus_idx < 0:
		return
	AudioServer.set_bus_mute(bus_idx, v <= 0.0)
	if v > 0.0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(v))
				

##It makes the input calls.
func _execute_input_command(button_index):
	#print(button_input_variation)
	if button_input_variation[button_index] == "" or button_input_variation[button_index] == null:
		print("It's button input is empty or null")
	else:
		#List of inputs.
		if button_input_variation[button_index].substr(0,6) == "res://":
			
			if button_input_variation[button_index] == "res://scenes/level.tscn":
				PauseMenu.current_scene = "ship"
			
			if script_type == "Pause":
				hide()
			get_tree().change_scene_to_file(button_input_variation[button_index])
		elif button_input_variation[button_index].substr(0,8) == "Continue":
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			hide()
		elif button_input_variation[button_index].substr(0,4) == "Quit":
			get_tree().quit()
		
