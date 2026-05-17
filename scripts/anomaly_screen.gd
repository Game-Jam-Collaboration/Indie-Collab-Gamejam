class_name AnomalyScreen
extends Node3D

const ANGEL_SCENE_PATH := "res://assets/blend_files/Biblically_Accurate_Angel.fbx"
const SCREEN_SHADER := preload("res://scripts/shaders/anomaly_screen.gdshader")
const VIEWPORT_MAX_SIZE := Vector2i(256, 192)
const VIEWPORT_MIN_SIZE := Vector2i(4, 3)
const MAX_DETAIL: float = 5.0

@export var screen_width: float = 0.35
@export var screen_height: float = 0.25
@export var camera_distance: float = 6.0
@export var camera_height: float = 0.6
@export var spin_speed: float = 0.6

var _sub_viewport: SubViewport
var _angel: Node3D
var _camera: Camera3D
var _key_light: DirectionalLight3D
var _screen_mesh: MeshInstance3D
var _shader_material: ShaderMaterial
var _detail_level: float = 0.0


func _ready() -> void:
	_setup_subviewport()
	_setup_screen()
	set_detail(0.0)


func _process(delta: float) -> void:
	if _angel:
		_angel.rotate_y(delta * spin_speed)
	_update_detail_from_record_button()


func _update_detail_from_record_button() -> void:
	var rb: Node = get_tree().get_first_node_in_group("record_button")
	if rb == null:
		return
	var level: float = float(rb.anomalies_recorded)
	if rb.recording and rb.has_method("get_recording_progress"):
		level += float(rb.get_recording_progress())
	set_detail(level)


func set_detail(level: float) -> void:
	_detail_level = clampf(level, 0.0, MAX_DETAIL)
	if _sub_viewport:
		# Squared curve keeps the early scans visibly low-res, ramps up sharply by scan 5.
		var t: float = _detail_level / MAX_DETAIL
		var curve: float = pow(t, 2.0)
		var w: int = int(round(lerpf(float(VIEWPORT_MIN_SIZE.x), float(VIEWPORT_MAX_SIZE.x), curve)))
		var h: int = int(round(lerpf(float(VIEWPORT_MIN_SIZE.y), float(VIEWPORT_MAX_SIZE.y), curve)))
		_sub_viewport.size = Vector2i(maxi(w, VIEWPORT_MIN_SIZE.x), maxi(h, VIEWPORT_MIN_SIZE.y))
	if _shader_material:
		_shader_material.set_shader_parameter("detail_level", _detail_level)


func get_detail() -> float:
	return _detail_level


func _setup_subviewport() -> void:
	_sub_viewport = SubViewport.new()
	_sub_viewport.size = VIEWPORT_MAX_SIZE
	_sub_viewport.transparent_bg = true
	_sub_viewport.disable_3d = false
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Build the dedicated world + environment BEFORE the viewport joins the tree,
	# so swapping its world later doesn't fight an already-initialized scenario.
	var world := World3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.1, 0.12, 1.0)
	env.ambient_light_energy = 0.6
	world.environment = env
	_sub_viewport.own_world_3d = true
	_sub_viewport.world_3d = world
	add_child(_sub_viewport)

	_camera = Camera3D.new()
	_camera.fov = 35.0
	_sub_viewport.add_child(_camera)
	_camera.look_at_from_position(Vector3(0, camera_height, camera_distance), Vector3.ZERO, Vector3.UP)

	_key_light = DirectionalLight3D.new()
	_key_light.rotation_degrees = Vector3(-40, 30, 0)
	_key_light.light_energy = 1.2
	_sub_viewport.add_child(_key_light)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(20, -150, 0)
	rim.light_color = Color(0.85, 0.92, 1.0)
	rim.light_energy = 0.5
	_sub_viewport.add_child(rim)

	var angel_packed: PackedScene = load(ANGEL_SCENE_PATH) as PackedScene
	if angel_packed != null:
		_angel = angel_packed.instantiate() as Node3D
	if _angel != null:
		_angel.position = Vector3.ZERO
		_sub_viewport.add_child(_angel)
		_play_first_animation(_angel)


func _setup_screen() -> void:
	_screen_mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(screen_width, screen_height)
	quad.orientation = PlaneMesh.FACE_Z
	_screen_mesh.mesh = quad
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = SCREEN_SHADER
	_shader_material.set_shader_parameter("viewport_texture", _sub_viewport.get_texture())
	_shader_material.set_shader_parameter("detail_level", 0.0)
	_shader_material.set_shader_parameter("max_detail_level", MAX_DETAIL)
	_screen_mesh.material_override = _shader_material
	add_child(_screen_mesh)


func _play_first_animation(node: Node) -> void:
	var anim_player: AnimationPlayer = _find_animation_player(node)
	if anim_player == null:
		push_warning("AnomalyScreen: no AnimationPlayer in angel scene")
		return
	var keys: PackedStringArray = anim_player.get_animation_list()
	if keys.size() > 0:
		anim_player.play(keys[0])
		return
	for lib_name in anim_player.get_animation_library_list():
		var lib: AnimationLibrary = anim_player.get_animation_library(lib_name)
		if lib == null:
			continue
		for anim_name in lib.get_animation_list():
			var key: String
			if String(lib_name) == "":
				key = String(anim_name)
			else:
				key = String(lib_name) + "/" + String(anim_name)
			anim_player.play(key)
			return
	push_warning("AnomalyScreen: AnimationPlayer has no animations")


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var ap := _find_animation_player(child)
		if ap != null:
			return ap
	return null
