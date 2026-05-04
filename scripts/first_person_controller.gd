class_name Player
extends CharacterBody3D


@export var mouse_sensitivity:float = 0.002
@export var move_speed:float = 5.0
@export var jump_force:float = 10.0
@export var vertical_speed:float = 10.0
@export var camera_pivot:Node3D

var camera_enabled := true


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
	if focused and camera_enabled:
		if event is InputEventMouseMotion:
			yaw -= event.relative.x * mouse_sensitivity
			pitch -= event.relative.y * mouse_sensitivity
			pitch = clamp(pitch, deg_to_rad(-89), deg_to_rad(89))
			rotation.y = yaw
			camera_pivot.rotation.x = pitch
		if event is InputEventMouseButton:
			if event.pressed:
				if event.button_index == 1:
					_interact_with()


func _physics_process(delta):
	if !focused: return
	var input_dir := Input.get_vector("MoveLeft", "MoveRight", "MoveForward", "MoveBackward")
	
	var direction := Vector3(input_dir.x, 0.0, input_dir.y)
	direction = (global_transform.basis * direction).normalized()

	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	if not is_on_floor():
		velocity.y -= 20.0 * delta
	elif Input.is_action_pressed("Jump"):
		velocity.y = jump_force

	move_and_slide()
	
	# Use this for debugging
	#_debug_raycast()


func _interact_with() -> void:
	var collision:CollisionObject3D = %Selector.get_collider()
	if collision != null and collision.is_in_group("Interactable"):
		if collision.has_method("_interact"):
			collision._interact()
		else:
			collision.get_parent()._interact()


func _debug_raycast() -> void:
	var collision = %Selector.get_collider()
	if collision != null and collision.is_in_group("Interactable"):
		print(collision)
