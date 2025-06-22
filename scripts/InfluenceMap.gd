extends RefCounted
class_name InfluenceMap
#TODO: split (again?!)
class ChunkData:
	var matrix: Array
	var net_influence_cache: Array # Cache for net influence calculations
	var dominant_fraction_cache: Array # Cache for dominant fraction
	var cache_valid: bool = false

	func _init(p_chunk_size: int = 16):
		matrix = []
		net_influence_cache = []
		dominant_fraction_cache = []
		for x in range(p_chunk_size):
			matrix.append([])
			net_influence_cache.append([])
			dominant_fraction_cache.append([])
			for y in range(p_chunk_size):
				matrix[x].append({}) # Empty dict per cell
				net_influence_cache[x].append(0.0)
				dominant_fraction_cache[x].append(FractionSystem.FractionType.NONE)

	func sample(x: int, y: int, fraction: FractionSystem.FractionType) -> float:
		return matrix[x][y].get(fraction, 0.0)
	
	func sample_net_influence(x: int, y: int) -> float:
		if not cache_valid:
			_rebuild_cache()
		return net_influence_cache[x][y]
	
	func sample_dominant_fraction(x: int, y: int) -> FractionSystem.FractionType:
		if not cache_valid:
			_rebuild_cache()
		return dominant_fraction_cache[x][y]
	
	func invalidate_cache():
		cache_valid = false
	
	func _rebuild_cache():
		var chunk_size = matrix.size()
		for x in range(chunk_size):
			for y in range(chunk_size):
				var result = _calculate_dominance_for_cell(x, y)
				net_influence_cache[x][y] = result.net_influence
				dominant_fraction_cache[x][y] = result.dominant_fraction
		cache_valid = true
	
	func _calculate_dominance_for_cell(x: int, y: int) -> Dictionary:
		var influences = matrix[x][y]
		if influences.is_empty():
			return {
				"net_influence": 0.0,
				"dominant_fraction": FractionSystem.FractionType.NONE
			}
		
		# Find the strongest influence
		var max_influence = 0.0
		var dominant_fraction = FractionSystem.FractionType.NONE
		
		for fraction in influences:
			var influence = influences[fraction]
			if influence > max_influence:
				max_influence = influence
				dominant_fraction = fraction
		
		if dominant_fraction == FractionSystem.FractionType.NONE:
			return {
				"net_influence": 0.0,
				"dominant_fraction": FractionSystem.FractionType.NONE
			}
		
		# Calculate sum of opposing influences
		var opposing_sum = 0.0
		for fraction in influences:
			if fraction != dominant_fraction:
				opposing_sum += influences[fraction]
		
		# Net influence = max(0, dominant - sum(others))
		var net = max(0.0, max_influence - opposing_sum)
		
		return {
			"net_influence": net,
			"dominant_fraction": dominant_fraction
		}

var chunk_size: int = 16

var data: Dictionary = {} # Vector3i -> ChunkData


func _init(p_chunk_size: int = 16, p_grid_size: int = 16):
	data = {}
	chunk_size = p_chunk_size


# ----------------------------------------
# Spatial utilities
# ----------------------------------------

func world_to_grid(world_x: float, world_y: float, grid_scale: int = 25) -> Vector2i:
	var grid_x = int(world_x / grid_scale)
	var grid_y = int(world_y / grid_scale)
	return Vector2i(grid_x, grid_y)

func grid_to_chunk(grid_x: int, grid_y: int, mip_level: int) -> Vector2i:
	var size = chunk_size * (1 << mip_level)
	return Vector2i(grid_x / size, grid_y / size)

func grid_to_local(grid_x: int, grid_y: int, mip_level: int) -> Vector2i:
	var size = chunk_size * (1 << mip_level)
	var local_x = (grid_x % size) / (1 << mip_level)
	var local_y = (grid_y % size) / (1 << mip_level)
	return Vector2i(local_x, local_y)


func _make_chunk_key(grid_x: int, grid_y: int, mip_level: int) -> Vector3i:
	var chunk = grid_to_chunk(grid_x, grid_y, mip_level)
	return Vector3i(chunk.x, chunk.y, mip_level)

func _create_new_chunk() -> ChunkData:
	return ChunkData.new(chunk_size)

# ----------------------------------------
# View utilities
# ----------------------------------------

func get_visible_chunks_data(padding: int, viewport: Viewport, camera: Camera2D, mip_level: int) -> Array:
	var chunks_data = []
	var chunks_keys = get_chunks_in_view(viewport, camera, mip_level, padding)
	
	for key in chunks_keys:
		if not data.has(key):
			if mip_level == 0:
				data[key] = _create_new_chunk()
			else:
				_generate_chunk_at_mip(key)
		
		var chunk_data = data[key]
		var world_origin = Vector2i(
			key.x * chunk_size * (1 << mip_level),
			key.y * chunk_size * (1 << mip_level)
		)
		
		chunks_data.append({
			"chunk": chunk_data,
			"world_origin": world_origin,
			"mip_level": mip_level
		})
	
	return chunks_data

func get_chunks_in_view(viewport: Viewport, camera: Camera2D, mip_level: int, padding: int = 1) -> Array:
	var bounds = get_visible_grid_bounds(padding, viewport, camera)
	
	var chunks_needed = []
	var chunk_min = grid_to_chunk(bounds.min_x, bounds.min_y, mip_level)
	var chunk_max = grid_to_chunk(bounds.max_x, bounds.max_y, mip_level)
	
	for x in range(chunk_min.x, chunk_max.x + 1):
		for y in range(chunk_min.y, chunk_max.y + 1):
			chunks_needed.append(Vector3i(x, y, mip_level))
	
	return chunks_needed


func get_visible_grid_bounds(padding: int, viewport: Viewport, camera: Camera2D, grid_scale: int = 25) -> Dictionary:
	var viewport_size = viewport.get_visible_rect().size
	var camera_pos = camera.global_position
	var zoom = camera.zoom.x

	var half_viewport = viewport_size / (2.0 * zoom)
	var world_top_left = camera_pos - half_viewport
	var world_bottom_right = camera_pos + half_viewport
	
	var grid_top_left = world_to_grid(world_top_left.x, world_top_left.y, grid_scale)
	var grid_bottom_right = world_to_grid(world_bottom_right.x, world_bottom_right.y, grid_scale)
	
	return {
		"min_x": grid_top_left.x - padding,
		"min_y": grid_top_left.y - padding,
		"max_x": grid_bottom_right.x + padding,
		"max_y": grid_bottom_right.y + padding
	}
# ----------------------------------------
# Data operations
# ----------------------------------------

func set_influence(grid_x: int, grid_y: int, fraction: FractionSystem.FractionType, value: float):
	var key = _make_chunk_key(grid_x, grid_y, 0)
	var local = grid_to_local(grid_x, grid_y, 0)

	if not data.has(key):
		data[key] = _create_new_chunk()

	data[key].matrix[local.x][local.y][fraction] = value
	data[key].invalidate_cache()
	_invalidate_mip_chain_from_base_chunk(key)


func get_influence(grid_x: int, grid_y: int, fraction: FractionSystem.FractionType, mip_level: int) -> float:
	var key = _make_chunk_key(grid_x, grid_y, mip_level)
	var local = grid_to_local(grid_x, grid_y, mip_level)

	if not data.has(key):
		if mip_level == 0:
			return 0.0
		else:
			_generate_chunk_at_mip(key)

	return data[key].sample(local.x, local.y, fraction)

# Fast way to get net influence of dominant faction only
func get_net_influence(grid_x: int, grid_y: int, mip_level: int) -> float:
	var key = _make_chunk_key(grid_x, grid_y, mip_level)
	var local = grid_to_local(grid_x, grid_y, mip_level)

	if not data.has(key):
		if mip_level == 0:
			return 0.0
		else:
			_generate_chunk_at_mip(key)

	return data[key].sample_net_influence(local.x, local.y)

# Fast way to get dominant fraction
func get_dominant_fraction(grid_x: int, grid_y: int, mip_level: int) -> FractionSystem.FractionType:
	var key = _make_chunk_key(grid_x, grid_y, mip_level)
	var local = grid_to_local(grid_x, grid_y, mip_level)

	if not data.has(key):
		if mip_level == 0:
			return FractionSystem.FractionType.NONE
		else:
			_generate_chunk_at_mip(key)

	return data[key].sample_dominant_fraction(local.x, local.y)

# Get influence for a specific faction in a cell (0 if not dominant)
func get_faction_dominance(grid_x: int, grid_y: int, fraction: FractionSystem.FractionType, mip_level: int) -> float:
	var dominant = get_dominant_fraction(grid_x, grid_y, mip_level)
	if dominant == fraction:
		return get_net_influence(grid_x, grid_y, mip_level)
	else:
		return 0.0

func get_influences(grid_x: int, grid_y: int, mip_level: int) -> Dictionary:
	var key = _make_chunk_key(grid_x, grid_y, mip_level)
	var local = grid_to_local(grid_x, grid_y, mip_level)

	if not data.has(key):
		if mip_level == 0:
			return {}
		else:
			_generate_chunk_at_mip(key)

	return data[key].matrix[local.x][local.y]


func get_mip_mapped_grid(viewport: Viewport, camera: Camera2D, mip_level: int, padding: int = 1, grid_scale: int = 25) -> Dictionary:
	"""
	Returns a complete mip-mapped grid matrix for the visible area and a converter function.
	Returns: {
		"matrix": 2D array of influence data,
		"converter": function that maps matrix[x][y] to world position,
		"bounds": the grid bounds used,
		"mip_level": the mip level used
	}
	"""
	var bounds = get_visible_grid_bounds(padding, viewport, camera, grid_scale)
	var chunks_data = get_visible_chunks_data(padding, viewport, camera, mip_level)
	
	# Calculate the size of the matrix in mip-mapped grid units
	var mip_scale = 1 << mip_level
	var matrix_width = (bounds.max_x - bounds.min_x + 1) / mip_scale
	var matrix_height = (bounds.max_y - bounds.min_y + 1) / mip_scale
	
	# Initialize the matrix
	var matrix = []
	for x in range(matrix_width):
		matrix.append([])
		for y in range(matrix_height):
			matrix[x].append({})
	
	# Fill the matrix with chunk data
	for chunk_info in chunks_data:
		var chunk = chunk_info.chunk
		var world_origin = chunk_info.world_origin
		
		for local_x in range(chunk_size):
			for local_y in range(chunk_size):
				var world_x = world_origin.x + local_x * mip_scale
				var world_y = world_origin.y + local_y * mip_scale
				
				# Convert to matrix coordinates
				var matrix_x = (world_x - bounds.min_x) / mip_scale
				var matrix_y = (world_y - bounds.min_y) / mip_scale
				
				if matrix_x >= 0 and matrix_x < matrix_width and matrix_y >= 0 and matrix_y < matrix_height:
					matrix[matrix_x][matrix_y] = chunk.matrix[local_x][local_y]
	
	# Create converter function
	var converter = func(matrix_x: int, matrix_y: int) -> Vector2:
		var world_x = bounds.min_x + matrix_x * mip_scale
		var world_y = bounds.min_y + matrix_y * mip_scale
		return Vector2(world_x * grid_scale, world_y * grid_scale)
	
	return {
		"matrix": matrix,
		"converter": converter,
		"bounds": bounds,
		"mip_level": mip_level,
		"mip_scale": mip_scale,
		"grid_scale": grid_scale
	}


# ----------------------------------------
# Lazy MIP generation
# ----------------------------------------

func _generate_chunk_at_mip(key: Vector3i):
	var mip = key.z
	if mip == 0:
		return # base chunks are written directly

	var parent_mip = mip - 1
	var chunk = _create_new_chunk()
	var world_origin_x = key.x * chunk_size * (1 << mip)
	var world_origin_y = key.y * chunk_size * (1 << mip)

	for x in range(chunk_size):
		for y in range(chunk_size):
			var accum := {}
			for dx in range(2):
				for dy in range(2):
					var child_x = world_origin_x + x * 2 + dx
					var child_y = world_origin_y + y * 2 + dy
					for f in FractionSystem.FractionType.values():
						var val = get_influence(child_x, child_y, f, parent_mip)
						if val != 0.0:
							accum[f] = accum.get(f, 0.0) + val
			for f in accum:
				accum[f] /= 4.0
			chunk.matrix[x][y] = accum

	data[key] = chunk


func _invalidate_mip_chain_from_base_chunk(base_key: Vector3i, max_mip: int = 7):
	for mip in range(1, max_mip + 1):
		var chunk_x = base_key.x / (1 << mip)
		var chunk_y = base_key.y / (1 << mip)
		var key = Vector3i(chunk_x, chunk_y, mip)
		data.erase(key)


# ----------------------------------------
# Chunk accessor
# ----------------------------------------

func generate_chunk(grid_x: int, grid_y: int, mip_level: int) -> ChunkData:
	var key = _make_chunk_key(grid_x, grid_y, mip_level)
	if not data.has(key):
		if mip_level == 0:
			data[key] = _create_new_chunk()
		else:
			_generate_chunk_at_mip(key)
	return data[key]


# ----------------------------------------
# Initalization
# ----------------------------------------

func initialize_from_image(image: Image, fraction: FractionSystem.FractionType, channel: int = 0):
	var width = image.get_width()
	var height = image.get_height()

	for y in range(height):
		for x in range(width):
			var pixel = image.get_pixel(x, y)
			var value = pixel[channel] # Red: 0, Green: 1, Blue: 2, Alpha: 3
			set_influence(x, y, fraction, value)

func initialize_with_multi_faction_noise(width: int, height: int, fractions: Array, noise_scale: float = 1.0, band_count: int = 3, seed_value: int = -1):
	var noise = FastNoiseLite.new()
	noise.seed = seed_value if seed_value != -1 else randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.05
	
	for y in range(50):
		for x in range(50):
			var noise_value = noise.get_noise_2d(x, y)
			# Map noise from [-1,1] to [0,1]
			var normalized_noise = (noise_value + 1.0) * 0.5
			
			# Determine which fraction's band this falls into
			var band_size = 1.0 / fractions.size()
			var fraction_index = min(floor(normalized_noise / band_size), fractions.size() - 1)
			var fraction = fractions[fraction_index]
			
			# Calculate position within the band (0.0 to 1.0)
			var band_position = (normalized_noise - (fraction_index * band_size)) / band_size
			
			# Convert to a value that's highest in the middle (0.5) and lowest at edges (0.0, 1.0)
			# Using a triangle distribution: 1.0 - 2.0 * |x - 0.5|
			var band_strength = 1.0 - 2.0 * abs(band_position - 0.5)
			
			# Scale the influence
			var influence_value = band_strength * noise_scale
			
			# Only set influence for the selected fraction in this cell
			set_influence(x, y, fraction, influence_value)
