extends StaticBody3D


@onready var mesh:MeshInstance3D = $Mesh
@onready var base_material = mesh.get_surface_override_material(0)
@onready var new_material = StandardMaterial3D.new()

var flipped := false


func _ready() -> void:
		new_material.albedo_color = Color.CYAN


func _interact() -> void:
	if flipped:
		mesh.set_surface_override_material(0, new_material)
	else:
		mesh.set_surface_override_material(0, base_material)
	flipped = not flipped
