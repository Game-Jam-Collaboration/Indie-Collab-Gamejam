class_name Anomaly
extends Node3D

@export var anomaly_id: String = "ANOM-01"

var recorded: bool = false


func _ready() -> void:
	add_to_group("anomaly")
