class_name Player
extends CharacterBody3D


@export var mouse_sensitivity:float = 0.002
@export var move_speed:float = 5.0
@export var jump_force:float = 10.0
@export var vertical_speed:float = 10.0
@export var camera_pivot:Node3D
@export var ship_movement_audio: AudioStreamPlayer3D = null

@onready var ship:Node3D = null

var first_person := true

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


func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if focused:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if event.keycode == KEY_E:
			if !get_tree().debug_collisions_hint:
				get_tree().debug_collisions_hint = true
			else:
				get_tree().debug_collisions_hint = false
			get_tree().reload_current_scene()
		elif event.keycode == KEY_T:
			%ThirdPersonCamera.make_current()
			first_person = false
		elif event.keycode == KEY_Q:
			ship.get_node("%PowerPanel").disassemble()
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


func _physics_process(delta):
	if hold_target:
		if not is_instance_valid(hold_target) or %Selector.get_collider() != hold_target:
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
	if !ship_movement_audio.playing:
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
	var tween = create_tween()
	var camera_position = camera_pivot.global_position
	var offset = camera_position + Vector3(randf_range(0,.1),randf_range(0,.1),randf_range(0,.1))
	tween.tween_property(camera_pivot, "global_position", offset, 0.01)
	tween.tween_property(camera_pivot, "global_position", camera_position, 0.1)
	tween.tween_property(camera_pivot, "global_position", offset, 0.01)
	tween.tween_property(camera_pivot, "global_position", camera_position, 0.1)
	tween.tween_property(camera_pivot, "global_position", offset, 0.01)
	tween.tween_property(camera_pivot, "global_position", camera_position, 0.1)
