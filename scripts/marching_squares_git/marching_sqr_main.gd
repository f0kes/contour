extends Node2D
class_name MarchingSquaresGit

@export var size_x: int = 50
@export var size_y: int = 50
@export var grid_scale: int = 25
@export var base_grid_scale: int = 25
@export var dot_size: float = 2.5
@export var grid_offset_vector: Vector2 = Vector2(75, 75)

# Colors for displaying
@export var dot_color_filled: Color = Color.RED
@export var dot_color_empty: Color = Color.BLUE
@export var line_color: Color = Color.WHITE
@export var influence_color_positive: Color = Color.RED
@export var influence_color_negative: Color = Color.BLUE

# Noise function and configuration
var noise: FastNoiseLite
var noise_octaves: int = 4
var noise_period: float = 20.0
var noise_persistence: float = 0.8
var noise_offset_vector: Vector2 = Vector2.ZERO

# Influence system
var influence_matrix: Array = []
var influence_radius: int = 3
var influence_strength: float = 5.0

# Zoom and camera
var camera: Camera2D
var dragging: bool = false
var drag_start_position: Vector2
var drag_start_camera_position: Vector2
var zoom_factor: float = 1.0
var min_zoom: float = 0.5
var max_zoom: float = 5.0

# Chunk system
var chunk_size: int = 16 # Size of each chunk in grid units
var chunks: Dictionary = {} # chunk_coord -> chunk_data
var dirty_chunks: Array = [] # List of chunk coordinates that need updating
var chunk_matrix_cache: Dictionary = {} # chunk_coord -> matrix data

# Value of each point that the Algorithm checks
var matrix: Array = []

# All possible configurations for each square with the corresponding connected points
var configurations = {
	0: [],
	15: [], # bin2int("1111")
	
	# 1 Dot
	1: ["e", "h"], # bin2int("0001")
	2: ["e", "f"], # bin2int("0010")
	4: ["f", "g"], # bin2int("0100")
	8: ["g", "h"], # bin2int("1000")
	
	# 2 Dots
	3: ["h", "f"], # bin2int("0011")
	6: ["e", "g"], # bin2int("0110")
	12: ["h", "f"], # bin2int("1100")
	9: ["e", "g"], # bin2int("1001")
	
	5: ["h", "e", "g", "f"], # bin2int("0101")
	10: ["h", "g", "e", "f"], # bin2int("1010")
	
	# 3 Dots
	7: ["h", "g"], # bin2int("0111")
	14: ["h", "e"], # bin2int("1110")
	13: ["e", "f"], # bin2int("1101")
	11: ["g", "f"] # bin2int("1011")
}

func _ready() -> void:
	# Setup camera
	camera = Camera2D.new()
	add_child(camera)
	camera.enabled = true
	
	# Randomize Godot Seed
	randomize()
	
	# Setup noise function
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.05
	
	# Initialize influence matrix
	initialize_influence_matrix()
	
	# Initial update
	update_values()

func world_to_chunk(world_pos: Vector2i) -> Vector2i:
	return Vector2i(world_pos.x / chunk_size, world_pos.y / chunk_size)

func get_chunks_in_view() -> Array:
	var bounds = get_visible_grid_bounds(1) # Small padding for chunks
	var mip_level = get_mip_level()
	
	var chunks_needed = []
	var chunk_min = world_to_chunk(Vector2i(bounds.min_x * mip_level, bounds.min_y * mip_level))
	var chunk_max = world_to_chunk(Vector2i(bounds.max_x * mip_level, bounds.max_y * mip_level))
	
	for x in range(chunk_min.x, chunk_max.x + 1):
		for y in range(chunk_min.y, chunk_max.y + 1):
			chunks_needed.append(Vector2i(x, y))
	
	return chunks_needed

func initialize_influence_matrix():
	influence_matrix.clear()
	for x in range(size_x):
		influence_matrix.append([])
		for y in range(size_y):
			influence_matrix[x].append(0.0)

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		var world_pos = get_global_mouse_position()
		var grid_pos = world_to_grid(world_pos)
		
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				add_influence(grid_pos, influence_strength)
			MOUSE_BUTTON_RIGHT:
				add_influence(grid_pos, -influence_strength)
			MOUSE_BUTTON_MIDDLE:
				dragging = true
				drag_start_position = event.position
				drag_start_camera_position = camera.global_position
			
			MOUSE_BUTTON_WHEEL_UP:
				zoom_factor = clamp(zoom_factor * 1.2, min_zoom, max_zoom)
				camera.zoom = Vector2(zoom_factor, zoom_factor)
				update_values()
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom_factor = clamp(zoom_factor / 1.2, min_zoom, max_zoom)
				camera.zoom = Vector2(zoom_factor, zoom_factor)
				update_values()
	
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = false
			update_values()
		
	
	elif event is InputEventMouseMotion and dragging:
		var delta = drag_start_position - event.position
		camera.global_position = drag_start_camera_position + delta / zoom_factor
		update_values()
	
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				initialize_influence_matrix()
				update_values()
			

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local_pos = world_pos - grid_offset_vector
	var grid_pos = local_pos / grid_scale
	return Vector2i(int(grid_pos.x), int(grid_pos.y))


func add_influence(center: Vector2i, strength: float):
	var affected_chunks = {} # Use dictionary to avoid duplicates
	
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
					new_influence = clamp(new_influence, -20.0, 20.0) # Fix: use new_influence
					influence_matrix[x][y] = new_influence
					
					# Mark chunk as dirty (avoid duplicates)
					var chunk_coord = world_to_chunk(Vector2i(x, y))
					affected_chunks[chunk_coord] = true
	
	# Add unique chunks to dirty list
	for chunk_coord in affected_chunks.keys():
		if chunk_coord not in dirty_chunks:
			dirty_chunks.append(chunk_coord)
	
	update_values()

func update_dirty_chunks():
	var mip_level = get_mip_level()
	
	for chunk_coord in dirty_chunks:
		generate_chunk(chunk_coord, mip_level)
	
	dirty_chunks.clear()
	queue_redraw()

func generate_chunk(chunk_coord: Vector2i, mip_level: int):
	var chunk_data = []
	var chunk_key = str(chunk_coord) + "_" + str(mip_level)
	
	var start_x = chunk_coord.x * chunk_size
	var start_y = chunk_coord.y * chunk_size
	var chunk_size_mipped = chunk_size / mip_level
	
	for x in range(chunk_size_mipped):
		chunk_data.append([])
		for y in range(chunk_size_mipped):
			var world_x = (start_x + x * mip_level)
			var world_y = (start_y + y * mip_level)
			
			# Sample noise
			var noise_value = noise.get_noise_2d(
				world_x + noise_offset_vector.x,
				world_y + noise_offset_vector.y
			)
			
			# Sample influence
			var influence_value = sample_influence_mipped(world_x, world_y, mip_level)
			
			# Combine
			var combined_value = noise_value + influence_value * 0.1
			chunk_data[x].append(1 if combined_value > 0 else 0)
	
	chunk_matrix_cache[chunk_key] = chunk_data

func set_influence(x: int, y: int, value: float, update: bool = true):
	if x >= 0 and x < size_x and y >= 0 and y < size_y:
		influence_matrix[x][y] = clamp(value, -20.0, 20.0)
		var chunk_coord = world_to_chunk(Vector2i(x, y))
		dirty_chunks.append(chunk_coord)
		if update:
			update_values()

func reset_influence():
	initialize_influence_matrix()
	update_values()


func get_value_at(x: int, y: int, mip_level: int) -> int:
	var chunk_coord = world_to_chunk(Vector2i(x, y))
	var chunk_key = str(chunk_coord) + "_" + str(mip_level)
	
	if chunk_key in chunk_matrix_cache:
		var chunk_data = chunk_matrix_cache[chunk_key]
		var local_x = (x - chunk_coord.x * chunk_size) / mip_level
		var local_y = (y - chunk_coord.y * chunk_size) / mip_level
		
		if local_x < chunk_data.size() and local_y < chunk_data[local_x].size():
			return chunk_data[local_x][local_y]
	
	return 0 # Default value if chunk not found


func get_mip_level() -> int:
	if zoom_factor > 2.0:
		return 1
	elif zoom_factor > 1.0:
		return 1
	elif zoom_factor > 0.5:
		return 2
	elif zoom_factor > 0.25:
		return 4
	elif zoom_factor > 0.1:
		return 8
	elif zoom_factor > 0.05:
		return 16
	elif zoom_factor > 0.01:
		return 32
	else:
		return 64

func update_values() -> void:
	#update_grid_values()
	ensure_visible_chunks_exist()
	update_dirty_chunks()
	queue_redraw()

func ensure_visible_chunks_exist():
	var chunks_needed = get_chunks_in_view()
	var mip_level = get_mip_level()
	
	for chunk_coord in chunks_needed:
		var chunk_key = str(chunk_coord) + "_" + str(mip_level)
		if chunk_key not in chunk_matrix_cache:
			generate_chunk(chunk_coord, mip_level)

func update_grid_values() -> void:
	matrix.clear()
	var mip_level = get_mip_level()
	
	var effective_size_x = max(4, size_x / mip_level)
	var effective_size_y = max(4, size_y / mip_level)
	
	for x in range(effective_size_x):
		matrix.append([])
		for y in range(effective_size_y):
			# Sample noise
			var noise_value = noise.get_noise_2d(
				(x * mip_level) + noise_offset_vector.x,
				(y * mip_level) + noise_offset_vector.y
			)
			
			# Sample influence (with mip-mapping)
			var influence_value = sample_influence_mipped(x * mip_level, y * mip_level, mip_level)
			
			# Combine noise and influence
			var combined_value = noise_value + influence_value * 0.1
			
			matrix[x].append(1 if combined_value > 0 else 0)

func sample_influence_mipped(x: int, y: int, mip_level: int) -> float:
	var total = 0.0
	var count = 0
	
	# Average influence over the mip area
	for dx in range(mip_level):
		for dy in range(mip_level):
			var sample_x = clamp(x + dx, 0, size_x - 1)
			var sample_y = clamp(y + dy, 0, size_y - 1)
			total += influence_matrix[sample_x][sample_y]
			count += 1
	
	return total / count if count > 0 else 0.0

func _draw() -> void:
	var mip_level = get_mip_level()
	
	# Draw influence background
	draw_influence_background(mip_level)
	# Draw dots (only at high zoom levels)
	draw_grid_dots()
	# Draw marching squares
	draw_marching_squares()

func draw_influence_background(mip_level: int):
	var effective_size_x = matrix.size()
	var effective_size_y = matrix[0].size() if matrix.size() > 0 else 0
	
	for x in range(effective_size_x):
		for y in range(effective_size_y):
			var influence = sample_influence_mipped(x * mip_level, y * mip_level, mip_level)
			if abs(influence) > 0.1:
				var color = influence_color_positive if influence > 0 else influence_color_negative
				color.a = clamp(abs(influence) * 0.05, 0.0, 0.3)
				
				var rect = Rect2(
					Vector2(x, y) * grid_scale + grid_offset_vector,
					Vector2(grid_scale, grid_scale)
				)
				draw_rect(rect, color)


func draw_grid_dots():
	var mip_level = get_mip_level()
	var quantized_dot_size = max(dot_size / mip_level, 1.0)
	var bounds = get_visible_grid_bounds(2)

	for x in range(bounds.min_x, bounds.max_x + 1):
		for y in range(bounds.min_y, bounds.max_y + 1):
			var value = get_value_at(x, y, mip_level)
			var color = dot_color_filled if value == 1 else dot_color_empty
			var pos = Vector2(x, y) * grid_scale + grid_offset_vector

			draw_circle(pos, quantized_dot_size, color)
func draw_marching_squares():
	var bounds = get_visible_grid_bounds(2)
	var mip_level = get_mip_level()
	
	
	for x in range(bounds.min_x, bounds.max_x, mip_level):
		for y in range(bounds.min_y, bounds.max_y, mip_level):
			draw_marching_square_cell(x, y)

func get_visible_grid_bounds(padding: int) -> Dictionary:
	var viewport_size = get_viewport().get_visible_rect().size
	var camera_pos = camera.global_position if camera else Vector2.ZERO
	var zoom = camera.zoom.x if camera else 1.0
	
	# Calculate world space bounds of the visible area
	var half_viewport = viewport_size / (2.0 * zoom)
	var world_top_left = camera_pos - half_viewport
	var world_bottom_right = camera_pos + half_viewport
	
	# Convert to grid coordinates
	var grid_top_left = world_to_grid(world_top_left)
	var grid_bottom_right = world_to_grid(world_bottom_right)
	
	# Remove matrix bounds checking - use world bounds instead
	var min_x = grid_top_left.x - padding
	var min_y = grid_top_left.y - padding
	var max_x = grid_bottom_right.x + padding
	var max_y = grid_bottom_right.y + padding
	
	return {
		"min_x": min_x,
		"min_y": min_y,
		"max_x": max_x,
		"max_y": max_y
	}


func draw_marching_square_cell(x: int, y: int):
	var mip_level = get_mip_level()
	var quantized_line_width = max(2.0 / mip_level, 1.5)
	
	# Corner point values
	var a = get_value_at(x, y, mip_level)
	var b = get_value_at(x + 1, y, mip_level)
	var c = get_value_at(x + 1, y + 1, mip_level)
	var d = get_value_at(x, y + 1, mip_level)
	
	# Skip uniform cells
	if a == b and b == c and c == d:
		return
	
	# Corner point positions - scale by mip_level
	var a_pos = Vector2(x, y) * grid_scale + grid_offset_vector
	var b_pos = Vector2(x + 1, y) * grid_scale + grid_offset_vector
	var c_pos = Vector2(x + 1, y + 1) * grid_scale + grid_offset_vector
	var d_pos = Vector2(x, y + 1) * grid_scale + grid_offset_vector
	
	# Edge midpoint positions
	var e = (b_pos + a_pos) / 2
	var f = (c_pos + b_pos) / 2
	var g = (d_pos + c_pos) / 2
	var h = (d_pos + a_pos) / 2
	
	var edge_points = {"e": e, "f": f, "g": g, "h": h}
	
	# Calculate configuration
	var configuration = a + b * 2 + c * 4 + d * 8
	var points_to_connect = configurations.get(configuration, [])
	
	# Draw lines
	for i in range(0, points_to_connect.size(), 2):
		if i + 1 < points_to_connect.size():
			var point_a = points_to_connect[i]
			var point_b = points_to_connect[i + 1]
			
			var point_a_pos = edge_points[point_a]
			var point_b_pos = edge_points[point_b]
			
			draw_line(point_a_pos, point_b_pos, line_color, quantized_line_width, true)
# Public interface
func increment_noise_offset():
	noise_offset_vector += Vector2(1, 1)

func set_size(new_size_x: int, new_size_y: int):
	size_x = new_size_x
	size_y = new_size_y
	initialize_influence_matrix()
	update_values()

func get_zoom_info() -> String:
	return "Zoom: %.2f, Mip Level: %d" % [zoom_factor, get_mip_level()]