extends Node2D
class_name InfluenceMapRenderer

@export var marching_squares: MarchingSquares 
@export var influence_map: InfluenceMap
@export var contour_threshold: float = 0.0
@export var update_frequency: float = 0.1 # Updates per second
@export var smoothing_iterations: int = 2
@export var normalize_influence: bool = true

# Visual settings
@export var faction_colors: Array[Color] = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW]
@export var contour_width: float = 3.0
@export var background_alpha: float = 0.3

var update_timer: float = 0.0
var last_influence_data: Array = []
var contour_meshes: Array[PackedVector2Array] = []

func _ready():
	# Auto-find components if not assigned
	if not influence_map:
		influence_map = InfluenceMap.instance
	
	if not marching_squares:
		marching_squares = get_node_or_null("MarchingSquares")
		if not marching_squares:
			marching_squares = MarchingSquares.new()
			add_child(marching_squares)
	
	# Configure marching squares to match influence map
	if influence_map and marching_squares:
		marching_squares.grid_size = Vector2i(influence_map.map_width, influence_map.map_height)
		marching_squares.cell_size = influence_map.tile_size
		marching_squares.threshold = contour_threshold
		marching_squares.interpolation = true
	
	# Initialize contour storage
	contour_meshes.resize(influence_map.num_factions if influence_map else 2)
	
	# Initial update
	update_contours()

func _process(delta):
	update_timer += delta
	if update_timer >= update_frequency:
		update_timer = 0.0
		update_contours()

# Convert influence map data to scalar field for marching squares
func convert_influence_to_scalar(faction_id: int) -> Array[float]:
	if not influence_map:
		return []
	
	var scalar_field: Array[float] = []
	var total_points = (influence_map.map_width + 1) * (influence_map.map_height + 1)
	scalar_field.resize(total_points)
	
	for y in range(influence_map.map_height + 1):
		for x in range(influence_map.map_width + 1):
			var influence_value = 0.0
			
			# Sample influence with bounds checking
			var sample_x = clamp(x, 0, influence_map.map_width - 1)
			var sample_y = clamp(y, 0, influence_map.map_height - 1)
			
			if faction_id < influence_map.influence_maps.size():
				influence_value = influence_map.influence_maps[faction_id][sample_x][sample_y]
			
			# Apply smoothing by averaging nearby cells
			if smoothing_iterations > 0:
				influence_value = smooth_sample(faction_id, sample_x, sample_y)
			
			# Normalize if requested
			if normalize_influence:
				influence_value = normalize_value(influence_value, faction_id, sample_x, sample_y)
			
			scalar_field[y * (influence_map.map_width + 1) + x] = influence_value
	
	return scalar_field

# Smooth influence values by averaging neighbors
func smooth_sample(faction_id: int, x: int, y: int) -> float:
	var total = 0.0
	var count = 0
	var radius = 1
	
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var nx = clamp(x + dx, 0, influence_map.map_width - 1)
			var ny = clamp(y + dy, 0, influence_map.map_height - 1)
			
			if faction_id < influence_map.influence_maps.size():
				total += influence_map.influence_maps[faction_id][nx][ny]
				count += 1
	
	return total / count if count > 0 else 0.0

# Normalize influence value relative to other factions
func normalize_value(value: float, faction_id: int, x: int, y: int) -> float:
	var max_influence = value
	
	# Find maximum influence at this position across all factions
	for f in range(influence_map.num_factions):
		if f != faction_id and f < influence_map.influence_maps.size():
			var other_value = influence_map.influence_maps[f][x][y]
			max_influence = max(max_influence, other_value)
	
	# Return relative dominance
	if max_influence > 0.0:
		return value / max_influence
	return 0.0

# Generate combined influence contour (faction 0 vs faction 1)
func get_combined_influence_scalar() -> Array[float]:
	if not influence_map or influence_map.num_factions < 2:
		return []
	
	var scalar_field: Array[float] = []
	var total_points = (influence_map.map_width + 1) * (influence_map.map_height + 1)
	scalar_field.resize(total_points)
	
	for y in range(influence_map.map_height + 1):
		for x in range(influence_map.map_width + 1):
			var sample_x = clamp(x, 0, influence_map.map_width - 1)
			var sample_y = clamp(y, 0, influence_map.map_height - 1)
			
			var faction0_influence = influence_map.influence_maps[0][sample_x][sample_y]
			var faction1_influence = influence_map.influence_maps[1][sample_x][sample_y]
			
			# Apply smoothing
			if smoothing_iterations > 0:
				faction0_influence = smooth_sample(0, sample_x, sample_y)
				faction1_influence = smooth_sample(1, sample_x, sample_y)
			
			# Calculate difference (positive = faction 0 dominance, negative = faction 1)
			var difference = faction0_influence - faction1_influence
			scalar_field[y * (influence_map.map_width + 1) + x] = difference
	
	return scalar_field

# Update all contours
func update_contours():
	if not influence_map or not marching_squares:
		return
	
	# Generate individual faction contours
	for faction_id in range(influence_map.num_factions):
		generate_faction_contour(faction_id)
	
	# Generate combined territory boundary
	generate_territory_boundary()
	
	queue_redraw()

# Generate contour for a specific faction
func generate_faction_contour(faction_id: int):
	if faction_id >= contour_meshes.size():
		contour_meshes.resize(faction_id + 1)
	
	var scalar_field = convert_influence_to_scalar(faction_id)
	marching_squares.update_field(scalar_field)
	contour_meshes[faction_id] = marching_squares.get_mesh_data()

# Generate territory boundary between factions
func generate_territory_boundary():
	var combined_field = get_combined_influence_scalar()
	marching_squares.set_threshold(0.0) # Zero crossing for boundaries
	marching_squares.update_field(combined_field)

# Render all contours
func _draw():
	if not influence_map:
		return
	
	# Draw influence field as background
	if background_alpha > 0.0:
		draw_influence_background()
	
	# Draw faction contours
	for faction_id in range(min(contour_meshes.size(), faction_colors.size())):
		if contour_meshes[faction_id].size() > 0:
			draw_faction_contour(faction_id)
	
	# Draw territory boundaries
	var boundary_mesh = marching_squares.get_mesh_data()
	if boundary_mesh.size() > 0:
		draw_territory_boundaries(boundary_mesh)

# Draw influence field as colored background
func draw_influence_background():
	for x in range(influence_map.map_width):
		for y in range(influence_map.map_height):
			var dominant_faction = get_dominant_faction(x, y)
			if dominant_faction >= 0:
				var color = faction_colors[dominant_faction]
				color.a = background_alpha
				var rect = Rect2(
					Vector2(x, y) * influence_map.tile_size,
					Vector2(influence_map.tile_size, influence_map.tile_size)
				)
				draw_rect(rect, color)

# Draw contour lines for a faction
func draw_faction_contour(faction_id: int):
	var mesh = contour_meshes[faction_id]
	var color = faction_colors[faction_id] if faction_id < faction_colors.size() else Color.WHITE
	
	for i in range(0, mesh.size() - 1, 2):
		draw_line(mesh[i], mesh[i + 1], color, contour_width)

# Draw territory boundary lines
func draw_territory_boundaries(boundary_mesh: PackedVector2Array):
	for i in range(0, boundary_mesh.size() - 1, 2):
		draw_line(boundary_mesh[i], boundary_mesh[i + 1], Color.WHITE, contour_width * 1.5)

# Get dominant faction at position
func get_dominant_faction(x: int, y: int) -> int:
	var max_influence = 0.0
	var dominant = -1
	
	for faction in range(influence_map.num_factions):
		var influence = influence_map.influence_maps[faction][x][y]
		if influence > max_influence:
			max_influence = influence
			dominant = faction
	
	return dominant if max_influence > 0.1 else -1

# Public interface
func set_contour_threshold(threshold: float):
	contour_threshold = threshold
	if marching_squares:
		marching_squares.set_threshold(threshold)
	update_contours()

func set_update_frequency(frequency: float):
	update_frequency = frequency

func force_update():
	update_contours()

# Get contour data for external use
func get_faction_contour_data(faction_id: int) -> PackedVector2Array:
	if faction_id < contour_meshes.size():
		return contour_meshes[faction_id]
	return PackedVector2Array()

func get_territory_boundary_data() -> PackedVector2Array:
	return marching_squares.get_mesh_data() if marching_squares else PackedVector2Array()
