class_name ShipNavigation
extends Node3D

signal heading_changed(new_heading: float)
signal position_changed(new_position: Vector3)

@export var translate_speed: float = 3.5
@export var rotate_speed_deg: float = 10.0
var speed_multiplier: float = 1.0

var simulated_position: Vector3 = Vector3.ZERO:
	set(value):
		if value == simulated_position:
			return
		simulated_position = value
		#print("Ship position: ", simulated_position)
		position_changed.emit(simulated_position)

var heading: float = 0.0:
	set(value):
		heading = wrapf(value, -PI, PI)
		heading_changed.emit(heading)


func _ready() -> void:
	add_to_group("ship_navigation")


func translate_forward(amount: float) -> void:
	var forward := Vector3(-sin(heading), 0.0, -cos(heading))
	simulated_position = simulated_position + forward * amount * speed_multiplier


func rotate_yaw(radians: float) -> void:
	heading = heading + radians * speed_multiplier


func get_simulated_transform() -> Transform3D:
	var t := Transform3D.IDENTITY
	t.basis = Basis(Vector3.UP, heading)
	t.origin = simulated_position
	return t
