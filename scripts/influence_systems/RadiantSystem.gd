extends RefCounted
class_name RadiantSystem

var influence_map: InfluenceMap

func _init(p_influence_map: InfluenceMap):
	influence_map = p_influence_map

func add_radiant(node: Node2D, strength: float, radius: float = 5.0):
	pass