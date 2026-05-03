extends Camera3D

@export var mouse_sensitivity: float = 0.002
@export var move_speed: float = 10.0
@export var sprint_multiplier: float = 3.0
@export var vertical_speed: float = 10.0

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

	if event is InputEventMouseMotion and focused:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(-89), deg_to_rad(89))

		# Build rotation (Y * X), no roll
		var q_yaw = Quaternion(Vector3.UP, yaw)
		var q_pitch = Quaternion(Vector3.RIGHT, pitch)
		transform.basis = Basis(q_yaw * q_pitch)


func _process(delta):
	if !focused: return
	var input_dir := Vector3.ZERO
	
	var forward := Vector3(-basis.z.x, 0, -basis.z.z)
	var right := Vector3(basis.x.x, 0, basis.x.z)

	if Input.is_action_pressed("MoveForward"):
		input_dir += forward
	if Input.is_action_pressed("MoveBackward"):
		input_dir += -forward
	if Input.is_action_pressed("MoveLeft"):
		input_dir += -right
	if Input.is_action_pressed("MoveRight"):
		input_dir += right

	if Input.is_action_pressed("Jump"):
		input_dir += Vector3.UP
	if Input.is_action_pressed("Crouch"):
		input_dir -= Vector3.UP

	# Normalize to prevent diagonal speed amplification
	input_dir = input_dir.normalized()

	var speed = move_speed
	if Input.is_action_pressed("Sprint"):
		speed *= sprint_multiplier

	position += input_dir * speed * delta
