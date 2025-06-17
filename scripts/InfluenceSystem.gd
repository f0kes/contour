extends RefCounted
class_name InfluenceSystem

var influence_matrix: Array = []
var size_x: int
var size_y: int
var influence_radius: int = 3
var influence_strength: float = 5.0

var radiants: Dictionary = {} # id -> RadiantSource
var next_radiant_id: int = 0

var world_to_grid: Callable

class RadiantSource:
	var id: int
	var node: Node2D
	var strength: float
	var radius: float
	var previous_position: Vector2i
	var current_influence: Dictionary = {} # Vector2i -> float
	
	func _init(p_id: int, p_node: Node2D, p_strength: float, p_radius: float):
		id = p_id
		node = p_node
		strength = p_strength
		radius = p_radius
		previous_position = Vector2i(node.global_position)

func _init(width: int, height: int, p_world_to_grid: Callable):
	size_x = width
	size_y = height
	world_to_grid = p_world_to_grid
	initialize_matrix()


func calculate_radiant_influence(radiant: RadiantSource) -> Dictionary:
	var influence_projection = {}
	var grid_pos = world_to_grid.call(Vector2i(radiant.node.global_position))
	var radius = int(radiant.radius)
	
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var x = grid_pos.x + dx
			var y = grid_pos.y + dy
			
			if x >= 0 and x < size_x and y >= 0 and y < size_y:
				var distance = Vector2(dx, dy).length()
				if distance <= radiant.radius:
					var falloff = 1.0 - (distance / radiant.radius)
					var influence_value = radiant.strength * falloff
					
					var point = Vector2i(x, y)
					influence_projection[point] = influence_value
	
	return influence_projection
	
func update_radiants() -> Array:
	var affected_chunks = {}
	
	for radiant in radiants.values():
		var current_pos = Vector2i(radiant.node.global_position)
		
		if current_pos != radiant.previous_position:
			# Calculate new influence projection
			radiant.current_influence = calculate_radiant_influence(radiant)
			radiant.previous_position = current_pos
			
			# Mark affected chunks
			for point in radiant.current_influence.keys():
				var chunk_coord = Vector2i(point.x / 16, point.y / 16)
				affected_chunks[chunk_coord] = true
	
	return affected_chunks.keys()


func add_radiant(node: Node2D, strength: float, radius: float = 5.0) -> int:
	var id = next_radiant_id
	next_radiant_id += 1
	
	var radiant = RadiantSource.new(id, node, strength, radius)
	radiant.current_influence = calculate_radiant_influence(radiant)
	radiants[id] = radiant
	
	return id




func remove_radiant(id: int):
	if radiants.has(id):
		radiants.erase(id)

func initialize_matrix():
	influence_matrix.clear()
	for x in range(size_x):
		influence_matrix.append([])
		for y in range(size_y):
			influence_matrix[x].append(0.0)



func add_influence(center: Vector2i, strength: float) -> Array:
	var affected_chunks = {}
	
	for dx in range(-influence_radius, influence_radius + 1):
		for dy in range(-influence_radius, influence_radius + 1):
			var x = center.x + dx
			var y = center.y + dy
			
			if x >= 0 and x < size_x and y >= 0 and y < size_y:
				var distance = Vector2(dx, dy).length()
				if distance <= influence_radius:
					var falloff = 1.0 - (distance / influence_radius)
					var new_influence = influence_matrix[x][y]
					new_influence += strength * falloff
					new_influence = clamp(new_influence, -20.0, 20.0)
					influence_matrix[x][y] = new_influence
					
					var chunk_coord = Vector2i(x / 16, y / 16) # chunk_size = 16
					affected_chunks[chunk_coord] = true
	
	return affected_chunks.keys()


func sample_influence_mipped(x: int, y: int, mip_level: int) -> float:
	var total = 0.0
	var count = 0
	
	# Add radiant projections first
	for radiant in radiants.values():
		for point in radiant.current_influence.keys():
			if point.x >= x and point.x < x + mip_level and point.y >= y and point.y < y + mip_level:
				total += radiant.current_influence[point]
				count += 1
	
	# Then add base influence matrix
	for dx in range(mip_level):
		for dy in range(mip_level):
			var sample_x = clamp(x + dx, 0, size_x - 1)
			var sample_y = clamp(y + dy, 0, size_y - 1)
			total += influence_matrix[sample_x][sample_y]
			count += 1
	
	return total / count if count > 0 else 0.0
	