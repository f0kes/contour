class_name InfluenceMap
extends Node2D

@export var map_width = 256
@export var map_height = 256
@export var num_factions = 2 # Extendable
@export var tile_size = 16

var influence_maps: Array = []

var map_texture: ImageTexture
var map_image: Image
static var instance: InfluenceMap
func _init():
	if instance != null:
		push_error("Only one instance of InfluenceMap is allowed")
	else:
		instance = self

func _ready():
	for _i in num_factions:
		var map = []
		for _x in map_width:
			map.append([])
			for _y in map_height:
				map[_x].append(0.0)
			influence_maps.append(map)

func clear():
	for f in num_factions:
		for x in map_width:
			for y in map_height:
				influence_maps[f][x][y] = 0.0

func add_influence(faction_id: int, center: Vector2, radius: int, strength: float):
	var cx = int(center.x / tile_size)
	var cy = int(center.y / tile_size)
	for dx in range(-radius, radius):
		for dy in range(-radius, radius):
			var x = cx + dx
			var y = cy + dy
			if x >= 0 and x < map_width and y >= 0 and y < map_height:
				var dist = Vector2(dx, dy).length()
				if dist <= radius:
					var falloff = clamp(1 - dist / radius, 0.0, 1.0)
					influence_maps[faction_id][x][y] += strength * falloff

func get_combined_map() -> Array:
	var result = []
	for x in map_width:
		result.append([])
		for y in map_height:
			result[x].append(influence_maps[0][x][y] - influence_maps[1][x][y])
	return result

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		var pos = get_global_mouse_position()
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				add_influence(0, pos, 4, 5.0) # Faction 0
				print("Left click at: ", pos)
			MOUSE_BUTTON_RIGHT:
				add_influence(1, pos, 4, 5.0) # Faction 1
				print("Right click at: ", pos)
