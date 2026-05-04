@tool
extends CSGCylinder3D

@export_tool_button("Brush", "Paint") var brush_tool = brush
@export var splotch: CSGMesh3D = null
@export var cleaned:CSGCombiner3D = null
@export var cleaner:CSGMesh3D = null


func brush() -> void:
	if cleaned != null:
		var brush_dupe:CSGCylinder3D = duplicate()
		brush_dupe.name = "dupe"

		cleaned.add_child(brush_dupe)
		if Engine.is_editor_hint():
			brush_dupe.owner = get_tree().edited_scene_root
		
		await get_tree().process_frame
		var new_mesh = cleaned.bake_static_mesh()
		print(new_mesh)
			
		cleaner.mesh = new_mesh
