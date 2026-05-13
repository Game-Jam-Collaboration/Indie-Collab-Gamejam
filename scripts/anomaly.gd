class_name Anomaly
extends Node3D

@export var anomaly_id:String = "ANOM-01"
@export var track:AudioStream = null

var recorded: bool = false
var discovered: bool = false


func _ready() -> void:
	add_to_group("anomaly")


func record() -> void:
	track.play()
	await get_tree().create_timer(5).timeout
