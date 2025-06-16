class_name Unit
extends Node2D

@export var faction_id: int = 0
@export var influence_radius := 5
@export var influence_strength := 10.0

var done: bool = false


func _process(_delta):
	if done:
		return
	InfluenceMap.instance.add_influence(faction_id, global_position, influence_radius, influence_strength)
	done = true
