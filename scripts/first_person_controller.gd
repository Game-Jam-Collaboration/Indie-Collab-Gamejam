extends CharacterBody3D


@export var mouse_sensitivity:float = 0.002
@export var move_speed:float = 5.0
@export var jump_force:float = 10.0
@export var sprint_multiplier:float = 30.0
@export var vertical_speed:float = 10.0
@export var camera_pivot:Node3D

@export var debug_laser:VoxelGI = null
@export var door:Node3D = null

var door_open := false

var yaw := 0.0
var pitch := 0.0
var focused:bool:
	get:
		return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if focused:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if event.keycode == KEY_E:
			_dev_light()

	if event is InputEventMouseMotion and focused:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(-89), deg_to_rad(89))
		rotation.y = yaw
		camera_pivot.rotation.x = pitch


func _physics_process(delta):
	
	if !focused: return
	var input_dir := Input.get_vector("MoveLeft", "MoveRight", "MoveForward", "MoveBackward")
	
	var direction := Vector3(input_dir.x, 0.0, input_dir.y)
	direction = (global_transform.basis * direction).normalized()
	
	var speed = move_speed
	if Input.is_action_pressed("Sprint"):
		speed *= sprint_multiplier

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	if not is_on_floor():
		velocity.y -= 20.0 * delta
	elif Input.is_action_pressed("Jump"):
		velocity.y = jump_force

	move_and_slide()


func _dev_light() -> void:
	debug_laser.visible = not debug_laser.visible
	var tween = create_tween()
	
	if !door_open:
		tween.tween_property(door, "position:y", -2.0, .5)
		door_open = true
	else:
		tween.tween_property(door, "position:y", 1.9, .5)
		door_open = false
