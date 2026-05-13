class_name Anomaly
extends Node3D

@export var anomaly_id: String = "ANOM-01"

var recorded: bool = false
var discovered: bool = false


func _ready() -> void:
	add_to_group("anomaly")


func record() -> void:
	await get_tree().create_timer(5).timeout
