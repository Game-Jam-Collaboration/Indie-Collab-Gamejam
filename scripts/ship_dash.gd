class_name ShipDash
extends Node3D

@export var navigation: ShipNavigation = null


func _ready() -> void:
	if navigation == null:
		return
	_propagate_nav(self)


func _propagate_nav(node: Node) -> void:
	if node is ShipDashButton:
		node.navigation = navigation
	elif node is ShipCompass:
		node.navigation = navigation
	for child in node.get_children():
		_propagate_nav(child)
