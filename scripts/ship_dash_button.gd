class_name ShipDashButton
extends StaticBody3D

enum Direction { FORWARD, REVERSE, TURN_LEFT, TURN_RIGHT }

@export var direction: Direction = Direction.FORWARD
@export var navigation: ShipNavigation = null
@export var press_offset: Vector3 = Vector3(0, -0.016, 0)

var _rest_position: Vector3
var _is_pressed: bool = false


func _ready() -> void:
	add_to_group("HoldInteractable")
	_rest_position = position


func on_press_start() -> void:
	_is_pressed = true
	position = _rest_position + press_offset


func on_press_end() -> void:
	_is_pressed = false
	position = _rest_position


func on_held(delta: float) -> void:
	if navigation == null:
		return
	match direction:
		Direction.FORWARD:
			navigation.translate_forward(navigation.translate_speed * delta)
		Direction.REVERSE:
			navigation.translate_forward(-navigation.translate_speed * delta)
		Direction.TURN_LEFT:
			navigation.rotate_yaw(deg_to_rad(navigation.rotate_speed_deg) * delta)
		Direction.TURN_RIGHT:
			navigation.rotate_yaw(-deg_to_rad(navigation.rotate_speed_deg) * delta)
