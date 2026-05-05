extends Area3D

@export var environment_light:Light3D = null
@export var emissive_object:MeshInstance3D

func assemble() -> void:
	if environment_light:
		environment_light.light_color = Color.CORNSILK
	if emissive_object:
		var new_material:StandardMaterial3D = emissive_object.mesh.surface_get_material(0).duplicate()
		new_material.emission = Color.WHITE_SMOKE
		new_material.emission_energy_multiplier = 3
		emissive_object.mesh.surface_set_material(0, new_material)
