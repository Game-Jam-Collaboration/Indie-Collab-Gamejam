class_name ScanProgressBar
extends MeshInstance3D

# Renders a small green progress bar in the AudioModule local space whenever a
# scan is in progress. Transparent background — only the fill is drawn.

@export var bar_width: float = 0.075
@export var bar_height: float = 0.012
@export var border_thickness: float = 0.0018

var _immediate: ImmediateMesh = ImmediateMesh.new()


func _ready() -> void:
	mesh = _immediate
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.GREEN
	mat.emission_enabled = true
	mat.emission = Color.GREEN
	mat.emission_energy_multiplier = 6.0
	material_override = mat
	visible = false


func _process(_delta: float) -> void:
	var rb: Node = get_tree().get_first_node_in_group("record_button")
	if rb == null:
		visible = false
		return
	if not rb.get("recording") or not rb.has_method("get_recording_progress"):
		visible = false
		return
	visible = true
	_rebuild(clampf(rb.get_recording_progress(), 0.0, 1.0))


func _rebuild(progress: float) -> void:
	_immediate.clear_surfaces()
	var hw: float = bar_width * 0.5
	var hh: float = bar_height * 0.5
	var t: float = border_thickness
	# Border outline (4 thin quads framing the full bar extent).
	_add_quad(-hw - t, -hh - t, hw + t, -hh)  # bottom
	_add_quad(-hw - t, hh, hw + t, hh + t)    # top
	_add_quad(-hw - t, -hh, -hw, hh)          # left
	_add_quad(hw, -hh, hw + t, hh)            # right
	# Fill grows from left edge to a fraction of full width.
	if progress > 0.0:
		var fx1: float = lerpf(-hw, hw, progress)
		_add_quad(-hw, -hh, fx1, hh)


func _add_quad(x0: float, y0: float, x1: float, y1: float) -> void:
	_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	_immediate.surface_add_vertex(Vector3(x0, y0, 0.0))
	_immediate.surface_add_vertex(Vector3(x1, y0, 0.0))
	_immediate.surface_add_vertex(Vector3(x0, y1, 0.0))
	_immediate.surface_add_vertex(Vector3(x1, y1, 0.0))
	_immediate.surface_end()
