extends RefCounted
class_name InfluenceSystem

var influence_matrix: Array = []
var fraction_influence_matrices: Array = []
var size_x: int
var size_y: int
var influence_strength: float = 1.0

var radiants: Dictionary = {} # id -> RadiantSource
var next_radiant_id: int = 0

var world_to_grid: Callable
var mark_dirty: Callable

var radiant_influence: Dictionary = {} # Vector2i -> float

var radiance_update_timer: float = 0.0
var radiance_update_interval: float = 0.1

class RadiantSource:
	var id: int
	var node: Node2D
	var strength: float
	var radius: float
	var previous_position: Vector2i
	var pos_changed: bool = false
	
	func _init(p_id: int, p_node: Node2D, p_strength: float, p_radius: float):
		id = p_id
		node = p_node
		strength = p_strength
		radius = p_radius
		previous_position = Vector2i(node.global_position)

func _init(width: int, height: int, p_world_to_grid: Callable, p_mark_dirty: Callable):
	size_x = width
	size_y = height
	world_to_grid = p_world_to_grid
	mark_dirty = p_mark_dirty
	initialize_matrix()

func update(delta):
	radiance_update_timer += delta
	if radiance_update_timer >= radiance_update_interval:
		apply_radiant_pressure()
		update_radiants()
		radiance_update_timer = 0.0

func update_radiants():
	# Clear the common radiant influence dictionary
	radiant_influence.clear()
	
	for radiant in radiants.values():
		var current_pos = Vector2i(radiant.node.global_position)
		if current_pos == radiant.previous_position:
			radiant.pos_changed = false
			radiant.previous_position = current_pos
			continue
		radiant.pos_changed = true
		# Always recalculate influence (could optimize to only do when position changed)
		var grid_pos = world_to_grid.call(current_pos)
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
						# Add to existing value or create new entry
						if radiant_influence.has(point):
							radiant_influence[point] += influence_value
						else:
							radiant_influence[point] = influence_value
							mark_dirty.call(point)
		
		radiant.previous_position = current_pos

func apply_radiant_pressure():
	for radiant in radiants.values():
		add_influence_until(
			world_to_grid.call(radiant.node.global_position),
			radiant.strength,
			0.3,
			radiant.radius
		)
func add_radiant(node: Node2D, strength: float, radius: float = 5.0) -> int:
	var id = next_radiant_id
	next_radiant_id += 1
	
	var radiant = RadiantSource.new(id, node, strength, radius)
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


func add_influence(center: Vector2i, strength: float, influence_radius: int = 4):
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
					mark_dirty.call(Vector2i(x, y))

func add_influence_until(center: Vector2i, strength: float, max_influence: float, influence_radius: int = 4):
	for dx in range(-influence_radius, influence_radius + 1):
		for dy in range(-influence_radius, influence_radius + 1):
			var x = center.x + dx
			var y = center.y + dy
			
			if x >= 0 and x < size_x and y >= 0 and y < size_y:
				var current_influence = influence_matrix[x][y]
				var same_sign = sign(current_influence) == sign(max_influence)
				var magnitude_over_max = abs(current_influence) >= abs(max_influence)
				if magnitude_over_max && same_sign:
					continue
				var distance = Vector2(dx, dy).length()
				if distance <= influence_radius:
					var falloff = 1.0 - (distance / influence_radius)
					var new_influence = influence_matrix[x][y]
					new_influence += strength * falloff
					new_influence = clamp(new_influence, -20.0, 20.0)
					influence_matrix[x][y] = new_influence
					mark_dirty.call(Vector2i(x, y))
	
	
func sample_influence_mipped(x: int, y: int, mip_level: int) -> float:
	if x < 0 or x >= size_x or y < 0 or y >= size_y:
		return 0.0
	var base_influence = influence_matrix[x][y]
	var radiant_value = 0.0
	
	var point = Vector2i(x, y)
	if radiant_influence.has(point):
		radiant_value = radiant_influence[point]
	
	return base_influence + radiant_value
