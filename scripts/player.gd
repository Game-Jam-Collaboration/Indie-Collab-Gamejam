class_name Player
extends CharacterBody3D

var intro_breath_two = load("res://assets/sounds/intro_breath_2.wav")
var suffocation_track = load("res://assets/sounds/suffocation.wav")


@export var mouse_sensitivity:float = 0.0014
@export var move_speed:float = 3.33
@export var jump_force:float = 10.0
@export var vertical_speed:float = 10.0
@export var camera_pivot:Node3D
@export var ship_movement_audio: AudioStreamPlayer3D = null
@export var step_interval:Timer = null

@onready var ship:Ship = null


var step_side = 0 # 0 == left foot, 1 == right foot

var first_person := true
var frozen := false
var suffocating := false

var in_hand:CollisionObject3D = null
var previous_pickup_parent:Node
var previous_pickup_transform:Variant
var assembling := false
var assembly_mechanism:Node = null
var hold_target:Node = null
var assembly_tween:Tween = null:
	set(value):
		if assembly_tween and assembly_tween.is_running(): assembly_tween.kill()
		assembly_tween = value
		return assembly_tween

var yaw := 0.0
var pitch := 0.0
var _suffocate_chain_id: int = 0
var _end_game_shake_amplitude: float = 0.0
var _end_game_fov_intensity: float = 0.0
var _camera_rest_position: Vector3 = Vector3.ZERO
var _camera_rest_captured: bool = false
var _camera_rest_fov: float = 75.0
var _camera_rest_fov_captured: bool = false
var _bob_phase: float = 0.0
var _suffocation_vignette_intensity: float = 0.0
var _suffocation_vignette_tween: Tween = null
const IDLE_BOB_RATE: float = 1.1
const WALK_BOB_RATE: float = 9.0
const IDLE_BOB_AMP: float = 0.004
const WALK_BOB_AMP: float = 0.022
const SUFFOCATION_BREATH_HZ: float = 0.45
var focused:bool:
	get:
		return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _ready():
	yaw = rotation.y
	pitch = camera_pivot.rotation.x
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ship = get_tree().root.get_node_or_null("Level/%Ship")
	if ship == null:
		push_warning("There is no ship in this scene, player controller may not work properly.")
	frozen = true
	await _intro_awaken()
	#await _intro_observe_broken_fixtures()
	frozen = false


func _unhandled_input(event):
	# Cursor + pause-menu state lives in PauseMenu autoload; nothing to do here for ESC.
	if frozen: return
	if focused and first_person:
		if event is InputEventMouseMotion:
			yaw -= event.relative.x * mouse_sensitivity
			pitch -= event.relative.y * mouse_sensitivity
			pitch = clamp(pitch, deg_to_rad(-89), deg_to_rad(89))
			rotation.y = yaw
			camera_pivot.rotation.x = pitch
		if event is InputEventMouseButton:
			if event.button_index == 1:
				if event.pressed:
					if assembling:
						%Selector.remove_exception(in_hand)
						remove_collision_exception_with(in_hand)
						in_hand.remove_from_group("Pickupable")
						assembling = false
						in_hand = null
						previous_pickup_parent = null
						previous_pickup_transform = null
						if assembly_mechanism:
							assembly_mechanism.assemble()
							assembly_mechanism = null
					elif %Holder.get_child_count() > 0:
						_release_pickup()
					else:
						var collision:CollisionObject3D = %Selector.get_collider()
						if collision and collision.is_in_group("HoldInteractable"):
							_start_hold(collision)
						else:
							_interact_with()
				else:
					_end_hold()


func _process(delta: float) -> void:
	_update_camera_offsets(delta)
	_update_suffocation_vignette()


func _update_suffocation_vignette() -> void:
	var rect: ColorRect = get_node_or_null("%SuffocationVignette") as ColorRect
	if rect == null or rect.material == null:
		return
	var pulse: float = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.001 * TAU * SUFFOCATION_BREATH_HZ)
	(rect.material as ShaderMaterial).set_shader_parameter("intensity", _suffocation_vignette_intensity * pulse)


func _update_camera_offsets(delta: float) -> void:
	if camera_pivot == null:
		return
	if not _camera_rest_captured:
		_camera_rest_position = camera_pivot.position
		_camera_rest_captured = true
	# Speed-driven bob: idle breath at standstill, larger amplitude while walking.
	var hspeed: float = Vector2(velocity.x, velocity.z).length()
	var walk_amount: float = clampf(hspeed / max(move_speed, 0.0001), 0.0, 1.0)
	var rate: float = lerpf(IDLE_BOB_RATE, WALK_BOB_RATE, walk_amount)
	var amp: float = lerpf(IDLE_BOB_AMP, WALK_BOB_AMP, walk_amount)
	_bob_phase += delta * rate
	var bob_offset := Vector3(
		cos(_bob_phase * 0.5) * amp * 0.4,
		sin(_bob_phase) * amp,
		0.0
	)
	# End-game shake adds on top, using a Lissajous pattern in world time.
	var shake_offset := Vector3.ZERO
	if _end_game_shake_amplitude > 0.0:
		var ph: float = (Time.get_ticks_msec() * 0.001) * TAU
		shake_offset = Vector3(
			sin(ph * 7.3),
			cos(ph * 5.9),
			sin(ph * 11.1) * 0.5
		) * _end_game_shake_amplitude
	camera_pivot.position = _camera_rest_position + bob_offset + shake_offset

	# Rotational shake + heartbeat FOV squeeze, applied to the Camera child so
	# they don't fight the player's pitch/yaw on camera_pivot.
	var cam: Camera3D = get_node_or_null("%Camera") as Camera3D
	if cam != null:
		if not _camera_rest_fov_captured:
			_camera_rest_fov = cam.fov
			_camera_rest_fov_captured = true
		if _end_game_fov_intensity > 0.0:
			var t_sec: float = Time.get_ticks_msec() * 0.001
			var t_phase: float = t_sec * TAU
			cam.rotation = Vector3(
				sin(t_phase * 6.1),
				cos(t_phase * 8.7),
				sin(t_phase * 5.3)
			) * 0.015 * _end_game_fov_intensity
			# Heartbeat-locked FOV: squeezes ~4° narrower on each beat (1.8 Hz,
			# midpoint of the shader heartbeat_rate ramp 1.4 → 2.8).
			var beat: float = 0.5 + 0.5 * sin(t_sec * 1.8 * TAU)
			var fov_pulse: float = lerpf(0.0, 4.0, _end_game_fov_intensity) * beat
			cam.fov = _camera_rest_fov - fov_pulse
		elif _camera_rest_fov_captured and not is_equal_approx(cam.fov, _camera_rest_fov):
			cam.fov = _camera_rest_fov
			cam.rotation = Vector3.ZERO


func _physics_process(delta):
	if frozen or !focused: return
	
	if hold_target:
		if not is_instance_valid(hold_target) or %Selector.get_collider() != hold_target:
			_end_hold()
		elif hold_target.has_method("can_press") and not hold_target.can_press():
			_end_hold()
		elif hold_target.has_method("on_held"):
			hold_target.on_held(delta)

	if in_hand:
		assembly_mechanism = %Selector.get_collider()
		if assembly_mechanism and assembly_mechanism.is_in_group("AssemblyPoint"):
			var assembly_point = assembly_mechanism.get_node("%AssemblyPoint") 
			in_hand.reparent(assembly_point)
			assembly_tween = create_tween()
			assembly_tween.tween_property(in_hand, "position", Vector3.ZERO, .2)
			assembly_tween.tween_property(in_hand, "rotation", Vector3.ZERO, .2)
			assembling = true
		else:
			assembling = false
		if !assembling:
			if in_hand.get_parent() != %Holder:
				in_hand.reparent(%Holder)
				assembly_tween = create_tween()
				assembly_tween.tween_property(in_hand, "position", Vector3.ZERO, .15)
				assembly_tween.tween_property(in_hand, "rotation", Vector3.ZERO, .15)

	var input_dir := Input.get_vector("MoveLeft", "MoveRight", "MoveForward", "MoveBackward")
	
	var direction := Vector3(input_dir.x, 0.0, input_dir.y)
	direction = (global_transform.basis * direction).normalized()

	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		_handle_step()
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	move_and_slide()


func _handle_step()-> void:
	if step_interval.time_left > 0: return
	step_interval.start(0.34)
	if step_side == 0:
		%LeftFootstep.play()
		step_side = 1
	else:
		%RightFootstep.play()
		step_side = 0


func _interact_with() -> void:
	var collision:CollisionObject3D = %Selector.get_collider()
	if collision == null: return
	if collision.is_in_group("Interactable"):
		if collision.has_method("_interact"):
			collision._interact()
		else:
			collision.get_parent()._interact()
		return
	if collision.is_in_group("Pickupable"):
		_take_into_hand(collision, collision.get_parent())


func _take_into_hand(item: CollisionObject3D, drop_parent: Node) -> void:
	in_hand = item
	%Selector.add_exception(item)
	previous_pickup_parent = drop_parent
	previous_pickup_transform = item.global_transform
	if item is RigidBody3D:
		item.freeze = true
	item.reparent(%Holder)
	item.position = Vector3.ZERO
	item.rotation = Vector3.ZERO
	add_collision_exception_with(item)


func _release_pickup() -> void:
	%Selector.remove_exception(in_hand)
	remove_collision_exception_with(in_hand)
	in_hand.reparent(previous_pickup_parent)
	in_hand.freeze = false
	in_hand = null
	previous_pickup_parent = null
	previous_pickup_transform = null


func _start_hold(target: Node) -> void:
	var can_interact := true
	if target.has_method("can_press"):
		can_interact = target.can_press()
	if can_interact and !ship_movement_audio.playing:
		ship_movement_audio.pitch_scale = randf_range(0.95, 1.05)
		ship_movement_audio.play()
	hold_target = target
	if target.has_method("on_press_start"):
		target.on_press_start()


func _end_hold() -> void:
	if hold_target == null: return
	ship_movement_audio.stop()
	if is_instance_valid(hold_target) and hold_target.has_method("on_press_end"):
		hold_target.on_press_end()
	hold_target = null


func _attack_camera_shake() -> void:
	frozen = true
	var tween = create_tween()
	var camera_position = camera_pivot.global_position
	var offset = camera_position + Vector3(randf_range(0,.1),randf_range(0,.1),randf_range(0,.1))
	tween.tween_property(camera_pivot, "global_position", offset, 0.01)
	tween.tween_property(camera_pivot, "global_position", camera_position, 0.1)
	tween.tween_property(camera_pivot, "global_position", offset, 0.01)
	tween.tween_property(camera_pivot, "global_position", camera_position, 0.1)
	tween.tween_property(camera_pivot, "global_position", offset, 0.01)
	tween.tween_property(camera_pivot, "global_position", camera_position, 0.1)
	await tween.finished
	frozen = false


func _relieve_suffocation() -> void:
	suffocating = false
	_suffocate_chain_id += 1
	if %AudioStreamer.playing:
		%AudioStreamer.stop()
	var tween = create_tween()
	tween.tween_property(%FadeIn, "color", Color(0.0, 0.0, 0.0, 0.0), 0.2)
	_tween_suffocation_vignette(0.0, 0.25)


func _suffocate() -> void:
	if ship.record_button.anomalies_recorded == 4: return
	if suffocating: return
	suffocating = true
	_suffocate_chain_id += 1
	var my_id: int = _suffocate_chain_id
	%AudioStreamer.stream = suffocation_track
	%AudioStreamer.play()
	if not await _suffocate_stage(my_id, 0.1): return
	if not await _suffocate_stage(my_id, 0.2): return
	if not await _suffocate_stage(my_id, 0.3): return
	if not await _suffocate_stage(my_id, 0.4): return
	if not await _suffocate_stage(my_id, 1.0): return
	if not suffocating or my_id != _suffocate_chain_id:
		_relieve_suffocation()
		return
	get_tree().reload_current_scene()


func _suffocate_stage(my_id: int, fade_alpha: float) -> bool:
	if ship.record_button.anomalies_recorded == 4: return false
	var tween: Tween = create_tween()
	tween.tween_property(%FadeIn, "color", Color(0.0, 0.0, 0.0, fade_alpha), 0.5)
	# Red vignette tracks suffocation severity, slightly amplified for visibility.
	_tween_suffocation_vignette(clampf(fade_alpha * 1.25, 0.0, 1.0), 0.5)
	var elapsed: float = 0.0
	while elapsed < 3.0:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
		if not suffocating or my_id != _suffocate_chain_id:
			_relieve_suffocation()
			return false
	return true


func _intro_awaken() -> void:
	camera_pivot.rotation_degrees.x = -90
	await get_tree().create_timer(3.25).timeout
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(camera_pivot, "rotation_degrees:x", 0, 0.6)
	tween.tween_property(%FadeIn, "color", Color(0.0, 0.0, 0.0, 0.0), .3)
	%AudioStreamer.play()
	await get_tree().create_timer(1.2).timeout



func _intro_observe_broken_fixtures() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation_degrees:y", -39, 0.38)
	tween.tween_property(camera_pivot, "rotation_degrees:x", -22, 0.38)
	await tween.finished
	await get_tree().create_timer(.8).timeout
	
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation_degrees:y", -56, 0.38)
	tween.tween_property(camera_pivot, "rotation_degrees:x", 0, 0.38)
	await tween.finished
	await get_tree().create_timer(.8).timeout
	
	
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation_degrees:y", -39, 0.38)
	tween.tween_property(camera_pivot, "rotation_degrees:x", -22, 0.38)
	await tween.finished
	await get_tree().create_timer(.8).timeout


	tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera_pivot, "rotation_degrees:x", 0, .7)
	await tween.finished


	tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	%AudioStreamer.stream = intro_breath_two
	%AudioStreamer.play()
	tween.tween_property(camera_pivot, "rotation_degrees:x", 2, 1.07)
	tween.tween_property(camera_pivot, "rotation_degrees:x", 2, .45)
	tween.tween_property(camera_pivot, "rotation_degrees:x", 0, 0.98)
	yaw = rotation.y
	pitch = camera_pivot.rotation.x
	await tween.finished


func end_game():
	# Power off the moment the chase angel reaches the player. The shutdown
	# locks the panel so the player can't re-energize anything once the angels
	# are inbound — the fuse pops right back out if they try.
	if ship != null and ship.fuse_panel != null:
		if ship.fuse_panel.has_method("end_game_shutdown"):
			ship.fuse_panel.end_game_shutdown()
		else:
			ship.fuse_panel.disassemble()
	var audio: AudioStreamPlayer3D = null
	if ship != null and ship.record_button != null:
		if ship.record_button.has_method("play_end_game_audio"):
			ship.record_button.play_end_game_audio()
		if ship.record_button.has_node("AnomalyRecording"):
			audio = ship.record_button.get_node("AnomalyRecording") as AudioStreamPlayer3D
	# Plan the fade for 1 second before the last-anomaly clip ends.
	var audio_seconds: float = 18.0
	if audio != null and audio.stream != null:
		audio_seconds = audio.stream.get_length() / max(audio.pitch_scale, 0.01)
	var fade_after: float = max(0.0, audio_seconds - 1.0)
	await get_tree().create_timer(4.0).timeout
	# Kick off the angel reveal in the background; the fade is locked to audio length.
	_angel_reveal()
	await get_tree().create_timer(max(0.0, fade_after - 4.0)).timeout
	var tween = create_tween()
	tween.tween_property(%FadeIn, "color", Color(0.0, 0.0, 0.0, 1.0), .3)
	await tween.finished
	get_tree().paused = true
	await get_tree().create_timer(3).timeout
	# Flag is consumed by MainMenu's _ready, which also unpauses the tree once
	# the old scene (and its still-playing audio nodes) has been freed.
	if PauseMenu != null:
		PauseMenu.skip_menu_intro = true
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _angel_reveal() -> void:
	# Don't freeze the player — let them look around as the angels approach.
	var camera_xform: Transform3D = camera_pivot.global_transform
	var forward: Vector3 = -camera_xform.basis.z
	var back: Vector3 = camera_xform.basis.z
	var right: Vector3 = camera_xform.basis.x
	var left: Vector3 = -camera_xform.basis.x
	# Thirteen angels — 8 around the horizon, 5 from the upper hemisphere so a
	# player looking up still sees them. Each is one mesh + one tween.
	var up: Vector3 = camera_xform.basis.y
	_spawn_approach_angel(camera_xform, forward)
	_spawn_approach_angel(camera_xform, back)
	_spawn_approach_angel(camera_xform, left)
	_spawn_approach_angel(camera_xform, right)
	_spawn_approach_angel(camera_xform, (forward + left).normalized())
	_spawn_approach_angel(camera_xform, (forward + right).normalized())
	_spawn_approach_angel(camera_xform, (back + left).normalized())
	_spawn_approach_angel(camera_xform, (back + right).normalized())
	_spawn_approach_angel(camera_xform, up)
	_spawn_approach_angel(camera_xform, (up + forward).normalized())
	_spawn_approach_angel(camera_xform, (up + back).normalized())
	_spawn_approach_angel(camera_xform, (up + left).normalized())
	_spawn_approach_angel(camera_xform, (up + right).normalized())
	var down: Vector3 = -up
	_spawn_approach_angel(camera_xform, down)
	_spawn_approach_angel(camera_xform, (down + forward).normalized())
	_spawn_approach_angel(camera_xform, (down + back).normalized())

	# Lightweight screen-space horror pass: 5-tap blur + chromatic aberration +
	# vignette + grain. ~7 texture samples per pixel, math elsewhere. Active
	# only during the end-game so the back-buffer copy cost is one-shot.
	var blur_shader: Shader = preload("res://scripts/shaders/endgame_blur.gdshader")
	var blur_mat: ShaderMaterial = ShaderMaterial.new()
	blur_mat.shader = blur_shader
	blur_mat.set_shader_parameter("blur_amount", 0.0)
	blur_mat.set_shader_parameter("brightness", 0.0)
	blur_mat.set_shader_parameter("vignette_strength", 0.0)
	blur_mat.set_shader_parameter("chromatic_aberration", 0.0)
	blur_mat.set_shader_parameter("grain_strength", 0.0)
	blur_mat.set_shader_parameter("red_shift", 0.0)
	blur_mat.set_shader_parameter("heartbeat_strength", 0.0)
	blur_mat.set_shader_parameter("heartbeat_rate", 1.4)
	blur_mat.set_shader_parameter("invert_strength", 0.0)
	blur_mat.set_shader_parameter("scanline_strength", 0.0)
	blur_mat.set_shader_parameter("pulse_zoom", 0.0)
	var blur_rect: ColorRect = ColorRect.new()
	blur_rect.material = blur_mat
	blur_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blur_rect.anchor_right = 1.0
	blur_rect.anchor_bottom = 1.0
	var fade_parent: Node = %FadeIn.get_parent()
	fade_parent.add_child(blur_rect)
	# Render the blur BEFORE the FadeIn overlay so fade-to-black stays crisp.
	fade_parent.move_child(blur_rect, %FadeIn.get_index())

	# Ramp every effect as the angels close in.
	var blur_tween: Tween = create_tween().set_parallel(true)
	blur_tween.tween_property(blur_mat, "shader_parameter/blur_amount", 14.0, 18.0)
	blur_tween.tween_property(blur_mat, "shader_parameter/brightness", 0.45, 18.0)
	blur_tween.tween_property(blur_mat, "shader_parameter/vignette_strength", 0.75, 18.0)
	blur_tween.tween_property(blur_mat, "shader_parameter/chromatic_aberration", 12.0, 18.0)
	blur_tween.tween_property(blur_mat, "shader_parameter/grain_strength", 0.18, 18.0)
	# Sick / wounded red wash + escalating heartbeat. Both are pure shader math.
	blur_tween.tween_property(blur_mat, "shader_parameter/red_shift", 0.55, 18.0)
	blur_tween.tween_property(blur_mat, "shader_parameter/heartbeat_strength", 1.0, 18.0)
	blur_tween.tween_property(blur_mat, "shader_parameter/heartbeat_rate", 2.8, 18.0)
	# Late-stage analog horror: brief color inverts and rolling scanlines that
	# only become visible in the back half of the ramp.
	blur_tween.tween_property(blur_mat, "shader_parameter/invert_strength", 0.65, 18.0).set_delay(7.0)
	blur_tween.tween_property(blur_mat, "shader_parameter/scanline_strength", 0.55, 18.0)
	# Heartbeat-synced radial squeeze. Shader uses the same heartbeat sine,
	# so this just sets the amplitude of the per-beat zoom.
	blur_tween.tween_property(blur_mat, "shader_parameter/pulse_zoom", 0.025, 18.0)

	# Amplitude ramp for the camera shake — pattern itself runs in _process so it
	# composes cleanly with the headbob.
	_end_game_shake_amplitude = 0.0
	var shake_ramp: Tween = create_tween()
	shake_ramp.tween_property(self, "_end_game_shake_amplitude", 0.04, 18.0)

	# Camera rotational shake + FOV claustrophobia tracked off the same amplitude.
	_end_game_fov_intensity = 0.0
	var fov_ramp: Tween = create_tween()
	fov_ramp.tween_property(self, "_end_game_fov_intensity", 1.0, 18.0)

	# Layered panting/breath audio that fades up under the existing rumble.
	if has_node("%AudioStreamer"):
		var streamer: AudioStreamPlayer3D = %AudioStreamer
		streamer.stop()
		streamer.stream = suffocation_track
		streamer.volume_db = -40.0
		streamer.pitch_scale = 1.35
		streamer.play()
		var breath_tween: Tween = create_tween()
		breath_tween.tween_property(streamer, "volume_db", 0.0, 15.0)

	await blur_tween.finished


func _spawn_approach_angel(camera_xform: Transform3D, dir: Vector3) -> void:
	var angel_packed: PackedScene = load("res://assets/blend_files/Biblically_Accurate_Angel.fbx") as PackedScene
	if angel_packed == null:
		return
	var angel: Node3D = angel_packed.instantiate() as Node3D
	if angel == null:
		return
	var start_pos: Vector3 = camera_xform.origin + dir * 14.0
	var end_pos: Vector3 = camera_xform.origin + dir * 2.5
	angel.scale = Vector3.ONE * 3.6
	get_tree().current_scene.add_child(angel)
	angel.look_at_from_position(start_pos, camera_xform.origin, Vector3.UP)
	_play_first_animation(angel)

	# Independent spin per angel: random axis, random speed, random direction.
	var base_basis: Basis = angel.basis
	var spin_axis: Vector3 = Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	).normalized()
	var spin_duration: float = randf_range(2.5, 9.0)
	var spin_dir: float = 1.0 if randf() < 0.5 else -1.0
	var spin: Tween = create_tween().set_loops()
	spin.tween_method(_spin_angel.bind(angel, base_basis, spin_axis, spin_dir), 0.0, 1.0, spin_duration)

	# Slight per-angel variation in approach speed so arrivals stagger.
	var approach_duration: float = randf_range(15.0, 21.0)
	var tween: Tween = create_tween()
	tween.tween_property(angel, "position", end_pos, approach_duration)


func _spin_angel(t: float, angel: Node3D, base_basis: Basis, axis: Vector3, direction: float) -> void:
	if is_instance_valid(angel):
		angel.basis = base_basis * Basis(axis, t * TAU * direction)


func _tween_suffocation_vignette(target: float, duration: float) -> void:
	if _suffocation_vignette_tween != null and _suffocation_vignette_tween.is_running():
		_suffocation_vignette_tween.kill()
	_suffocation_vignette_tween = create_tween()
	_suffocation_vignette_tween.tween_property(self, "_suffocation_vignette_intensity", target, duration)


func _play_first_animation(node: Node) -> void:
	var anim_player: AnimationPlayer = _find_animation_player(node)
	if anim_player == null:
		push_warning("Angel: no AnimationPlayer found in imported scene")
		return
	var keys: PackedStringArray = anim_player.get_animation_list()
	if keys.size() > 0:
		anim_player.play(keys[0])
		return
	# Fallback: manual library iteration if get_animation_list returned nothing.
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
	push_warning("Angel: AnimationPlayer has no animations")


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var ap: AnimationPlayer = _find_animation_player(child)
		if ap != null:
			return ap
	return null
