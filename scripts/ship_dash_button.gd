class_name ShipDashButton
extends StaticBody3D

enum Direction { FORWARD, REVERSE, TURN_LEFT, TURN_RIGHT }

@export var direction: Direction = Direction.FORWARD
@export var navigation: ShipNavigation = null
@export var fuse_panel: FusePanel = null
@export var record_button: RecordButton = null
@export var press_offset: Vector3 = Vector3(0, 0.016, 0)
@export var indicator: MeshInstance3D = null
@export var indicator_off_material: Material = null
@export var indicator_on_material: Material = null
@export var indicator_disabled_material: Material = null
@export var ship_movement_audio: AudioStreamPlayer3D = null
@export var mesh:MeshInstance3D = null

const REENABLE_FLASH_DURATION: float = 1.2
const REENABLE_FLASH_PERIOD: float = 0.3
const PRESS_DEPRESS_DURATION: float = 0.08
const PRESS_RELEASE_DURATION: float = 0.14

var _rest_position: Vector3
var _is_pressed: bool = false
var _enabled: bool = false
var _flash_remaining: float = 0.0
var _press_tween: Tween = null


func _ready() -> void:
	add_to_group("HoldInteractable")
	_rest_position = mesh.position
	_refresh_indicator()


func _process(delta: float) -> void:
	var power_on := fuse_panel != null and fuse_panel.online
	var locked := record_button != null and record_button.recording
	var enabled := power_on and not locked
	if enabled != _enabled:
		var newly_enabled := enabled and not _enabled
		_enabled = enabled
		if newly_enabled:
			_flash_remaining = REENABLE_FLASH_DURATION
		else:
			_flash_remaining = 0.0
		_refresh_indicator()

	if _flash_remaining > 0.0:
		_flash_remaining -= delta
		if _flash_remaining <= 0.0:
			_flash_remaining = 0.0
			_refresh_indicator()
		else:
			var elapsed: float = REENABLE_FLASH_DURATION - _flash_remaining
			var phase: float = fmod(elapsed, REENABLE_FLASH_PERIOD) / REENABLE_FLASH_PERIOD
			var flash_on: bool = phase < 0.5
			if indicator != null:
				var mat: Material = indicator_on_material if flash_on else indicator_off_material
				if mat != null:
					indicator.material_override = mat


func can_press() -> bool:
	return _enabled


func on_press_start() -> void:
	if not _enabled:
		return
	_is_pressed = true
	_tween_mesh_to(_rest_position + press_offset, PRESS_DEPRESS_DURATION, Tween.EASE_OUT)
	_refresh_indicator()


func on_press_end() -> void:
	_is_pressed = false
	_tween_mesh_to(_rest_position, PRESS_RELEASE_DURATION, Tween.EASE_OUT, Tween.TRANS_BACK)
	_refresh_indicator()


func _tween_mesh_to(target: Vector3, duration: float, ease_kind: int, trans: int = Tween.TRANS_QUAD) -> void:
	if mesh == null:
		return
	if _press_tween != null and _press_tween.is_running():
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.set_trans(trans).set_ease(ease_kind)
	_press_tween.tween_property(mesh, "position", target, duration)


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
