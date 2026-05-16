extends MeshInstance3D

@export var bus_name := "Recordings"
@export var point_count := 128
@export var screen_width := .5
@export var screen_height := .5
@export var z_offset := 0.01
@export var sensitivity := 40.0
@export var audio_player:AudioStreamPlayer3D = null

var spectrum: AudioEffectSpectrumAnalyzerInstance
var values := PackedFloat32Array()
var immediate := ImmediateMesh.new()


func _ready() -> void:
	mesh = immediate
	values.resize(point_count)

	var shiny_mat := StandardMaterial3D.new()
	shiny_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shiny_mat.albedo_color = Color.GREEN
	shiny_mat.emission_enabled = true
	shiny_mat.emission = Color.GREEN
	shiny_mat.emission_energy_multiplier = 6.0
	material_override = shiny_mat

	var bus_idx := AudioServer.get_bus_index(bus_name)
	spectrum = AudioServer.get_bus_effect_instance(bus_idx, 0)


func _process(_delta: float) -> void:
	if spectrum == null: return
	
	var magnitude := Vector2.ZERO
	if audio_player.playing:
		magnitude = spectrum.get_magnitude_for_frequency_range(
			80.0,
			600.0,
			AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE
		)

	var value: float = clamp((magnitude.x + magnitude.y) * 0.5 * sensitivity, 0.0, 1.0)

	for i in range(point_count - 1):
		values[i] = values[i + 1]
		
	values[point_count - 1] = (value - 0.5) * 2.0
	_rebuild_line()


func _rebuild_line() -> void:
	immediate.clear_surfaces()
	immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

	for i in point_count:
		var t := float(i) / float(point_count - 1)
		var x: float = lerp(-screen_width * 0.5, screen_width * 0.5, t)
		var y := values[i] * screen_height * 0.5

		immediate.surface_add_vertex(Vector3(x, y, z_offset))

	immediate.surface_end()
