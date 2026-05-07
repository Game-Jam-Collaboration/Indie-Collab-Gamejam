class_name ShipCompass
extends Node3D

@export var navigation: ShipNavigation = null
@export var needle: Node3D = null


func _process(_delta: float) -> void:
	if navigation == null or needle == null:
		return
	needle.rotation.y = navigation.heading
