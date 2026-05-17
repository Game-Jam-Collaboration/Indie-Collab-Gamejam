extends PanelContainer

const VOLUME_LEVELS: Array = [1.0, 0.75, 0.5, 0.25, 0.0]
const SPEED_MULTIPLIERS: Array = [1.0, 2.0, 5.0, 10.0]

@export var button_input_variation : Array = []

@export var script_type : String
var current_scene = ""
var skip_menu_intro: bool = false
var _volume_index: int = 0
var _speed_index: int = 0
const MENU_MUSIC_SKIP_SECONDS: float = 13.0

var focused:bool:
	get:
		return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _ready() -> void:

	if script_type == "Pause":
		if get_tree().current_scene.name == "MainMenu":
			hide()
	elif script_type == "Main Menu":
		# Coming back from end_game leaves the tree paused so the dying ship
		# scene can't blast one frame of audio at us. Unpause here, then start
		# the menu track partway through if requested.
		if get_tree().paused:
			get_tree().paused = false
		# Always release the cursor on main menu, and clear the ship-scene flag
		# on the autoload so focus-in/out doesn't try to re-capture it later.
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if PauseMenu != null:
			PauseMenu.current_scene = ""
		if PauseMenu != null and PauseMenu.skip_menu_intro:
			PauseMenu.skip_menu_intro = false
			var audio_node := get_node_or_null("AudioStreamPlayer3D")
			if audio_node != null and audio_node.has_method("play"):
				var target_db: float = audio_node.volume_db
				audio_node.volume_db = -40.0
				audio_node.play(MENU_MUSIC_SKIP_SECONDS)
				var audio_tween: Tween = create_tween()
				audio_tween.tween_property(audio_node, "volume_db", target_db, 2.0)
			_fade_in_from_black(2.0)
			# Backdrop alone first, then buttons fade in on top after a beat.
			var buttons: Control = get_node_or_null("MarginContainer") as Control
			if buttons != null:
				buttons.modulate.a = 0.0
				var btn_tween: Tween = create_tween()
				btn_tween.tween_interval(3.0)
				btn_tween.tween_property(buttons, "modulate:a", 1.0, 1.5)

	#Connecting signals for buttons and mouse inputs.

	#Start or Continue in Pause
	get_node("MarginContainer/Control/Button").mouse_entered.connect(_mouse_entered.bind(""))
	get_node("MarginContainer/Control/Button").mouse_exited.connect(_mouse_exited.bind(""))
	get_node("MarginContainer/Control/Button").pressed.connect(_mouse_pressed.bind(0))

	#Exit
	get_node("MarginContainer/Control/Button3").mouse_entered.connect(_mouse_entered.bind(3))
	get_node("MarginContainer/Control/Button3").mouse_exited.connect(_mouse_exited.bind(3))
	get_node("MarginContainer/Control/Button3").pressed.connect(_mouse_pressed.bind(2))


func _fade_in_from_black(duration: float) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	var fade := ColorRect.new()
	fade.color = Color(0.0, 0.0, 0.0, 1.0)
	fade.anchor_right = 1.0
	fade.anchor_bottom = 1.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, duration)
	tw.tween_callback(canvas.queue_free)



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
				_cycle_speed()
			elif event.physical_keycode == KEY_BACKSLASH:
				_debug_skip_to_endgame()
			elif event.keycode == KEY_ESCAPE and current_scene == "ship":
				_toggle_pause()


func _toggle_pause() -> void:
	visible = not visible
	_apply_cursor_for_pause_state()


func _apply_cursor_for_pause_state() -> void:
	if visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _notification(what: int) -> void:
	if script_type != "Pause":
		return
	if current_scene != "ship":
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# Resync cursor whenever the window/app regains focus.
		_apply_cursor_for_pause_state()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _debug_skip_to_endgame() -> void:
	var rb: Node = get_tree().get_first_node_in_group("record_button")
	if rb != null and rb.has_method("debug_skip_to_endgame"):
		rb.debug_skip_to_endgame()


func _cycle_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEED_MULTIPLIERS.size()
	var m: float = SPEED_MULTIPLIERS[_speed_index]
	var nav: Node = get_tree().get_first_node_in_group("ship_navigation")
	if nav != null:
		nav.speed_multiplier = m
	var rb: Node = get_tree().get_first_node_in_group("record_button")
	if rb != null:
		rb.speed_multiplier = m


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
		
