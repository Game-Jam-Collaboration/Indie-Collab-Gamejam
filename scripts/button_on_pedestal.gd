@tool
extends Node3D

@export_tool_button("Push", "InputEventShortcut") var push = _interact

var tween_length := 0.25

func _interact() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(%Button, "position:x", %Button.position.x - 0.025, tween_length)
	tween.tween_property(%Button, "position:y", %Button.position.y - 0.05, tween_length)
	await tween.finished
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(%Button, "position:x", %Button.position.x + 0.025, tween_length)
	tween.tween_property(%Button, "position:y", %Button.position.y + 0.05, tween_length)
	get_tree().root.get_node("Playground/%AirlockDoor")._open()
