@tool
class_name AssemblyStatusPanel
extends Node3D


@export var light_count: int = 2:
	set(value):
		light_count = max(0, value)
		_request_rebuild()

@export var spacing: float = 0.15:
	set(value):
		spacing = value
		_request_rebuild()

@export var light_radius: float = 0.05:
	set(value):
		light_radius = max(0.001, value)
		_request_rebuild()

@export var pending_color: Color = Color(1, 0, 0):
	set(value):
		pending_color = value
		_request_rebuild()

@export var complete_color: Color = Color(0, 1, 0):
	set(value):
		complete_color = value
		_refresh_colors()

@export var emission_energy: float = 4.0:
	set(value):
		emission_energy = max(0.0, value)
		_request_rebuild()

var _completed: Array[bool] = []
var _lights: Array[MeshInstance3D] = []


func _ready() -> void:
	_rebuild()


func _request_rebuild() -> void:
	if is_inside_tree():
		_rebuild()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_lights.clear()
	_completed.clear()
	_completed.resize(light_count)

	if light_count <= 0:
		return

	var sphere := SphereMesh.new()
	sphere.radius = light_radius
	sphere.height = light_radius * 2.0

	var total_width := spacing * float(light_count - 1)
	var start_x := -total_width * 0.5

	for i in light_count:
		var mesh := MeshInstance3D.new()
		mesh.name = "Light%d" % i
		mesh.mesh = sphere
		mesh.material_override = _make_material(pending_color)
		mesh.position = Vector3(start_x + spacing * i, 0.1, 0)
		add_child(mesh)
		_lights.append(mesh)


func _refresh_colors() -> void:
	for i in _lights.size():
		var done: bool = i < _completed.size() and _completed[i]
		_lights[i].material_override = _make_material(complete_color if done else pending_color)


func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = emission_energy
	return mat


func mark_complete(index: int) -> void:
	if index < 0 or index >= _completed.size():
		return
	_completed[index] = true
	if index < _lights.size():
		_lights[index].material_override = _make_material(complete_color)


func mark_pending(index: int) -> void:
	if index < 0 or index >= _completed.size():
		return
	_completed[index] = false
	if index < _lights.size():
		_lights[index].material_override = _make_material(pending_color)


func advance() -> int:
	for i in _completed.size():
		if not _completed[i]:
			mark_complete(i)
			return i
	return -1


func reset() -> void:
	for i in _completed.size():
		_completed[i] = false
	_refresh_colors()


func is_complete() -> bool:
	if _completed.is_empty():
		return false
	return _completed.all(func(c): return c)
