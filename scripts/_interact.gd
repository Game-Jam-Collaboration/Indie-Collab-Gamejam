extends StaticBody3D


@onready var mesh:MeshInstance3D = $Mesh


func _interact() -> void:
	var new_material = StandardMaterial3D.new()
	new_material.albedo_color = Color.HONEYDEW
	mesh.mesh.surface_set_material(0, new_material)
