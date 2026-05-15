class_name ShipDashButton
extends StaticBody3D

enum Direction { FORWARD, REVERSE, TURN_LEFT, TURN_RIGHT }

@export var direction: Direction = Direction.FORWARD
@export var navigation: ShipNavigation = null
@export var fuse_panel: FusePanel = null
@export var record_button: RecordButton = null
@export var press_offset: Vector3 = Vector3(0, -0.016, 0)
@export var indicator: MeshInstance3D = null
@export var indicator_off_material: Material = null
@export var indicator_on_material: Material = null
@export var indicator_disabled_material: Material = null
@export var ship_movement_audio: AudioStreamPlayer3D = null

var _rest_position: Vector3
var _is_pressed: bool = false
var _enabled: bool = false


func _ready() -> void:
	add_to_group("HoldInteractable")
	_rest_position = position
	_refresh_indicator()


func _process(_delta: float) -> void:
	var power_on := fuse_panel != null and fuse_panel.online
	var locked := record_button != null and record_button.recording
	var enabled := power_on and not locked
	if enabled != _enabled:
		_enabled = enabled
		_refresh_indicator()


func can_press() -> bool:
	return _enabled


func on_press_start() -> void:
	if not _enabled:
		return
	_is_pressed = true
	position = _rest_position + press_offset
	_refresh_indicator()


func on_press_end() -> void:
	_is_pressed = false
	position = _rest_position
	_refresh_indicator()


func on_held(delta: float) -> void:
	if not _enabled or navigation == null:
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


func _refresh_indicator() -> void:
	if indicator == null:
		return
	var mat: Material
	if not _enabled:
		mat = indicator_disabled_material if indicator_disabled_material != null else indicator_off_material
	elif _is_pressed:
		mat = indicator_on_material
	else:
		mat = indicator_off_material
	if mat != null:
		indicator.material_override = mat
