class_name MarchingSquares
extends Node2D


# Marching squares lookup table for edge configurations
const EDGE_TABLE = [
	0x0, 0x9, 0x3, 0xa, 0x6, 0xf, 0x5, 0xc,
	0xc, 0x5, 0xf, 0x6, 0xa, 0x3, 0x9, 0x0
]

# Vertex positions for each edge (normalized to 0-1)
const EDGE_VERTICES = [
	[Vector2(0.5, 0), Vector2(1, 0.5)], # Edge 0: top, right
	[Vector2(1, 0.5), Vector2(0.5, 1)], # Edge 1: right, bottom
	[Vector2(0.5, 1), Vector2(0, 0.5)], # Edge 2: bottom, left
	[Vector2(0, 0.5), Vector2(0.5, 0)] # Edge 3: left, top
]

@export var grid_size: Vector2i = Vector2i(64, 64)
@export var cell_size: float = 8.0
@export var threshold: float = 0.5
@export var interpolation: bool = true

var scalar_field: Array[float] = []
var mesh_data: PackedVector2Array = []

func _ready():
	generate_test_field()
	generate_contours()

# Generate a test scalar field (you can replace this with your own data)
func generate_test_field():
	scalar_field.clear()
	scalar_field.resize((grid_size.x + 1) * (grid_size.y + 1))
	
	var center = Vector2(grid_size.x * 0.5, grid_size.y * 0.5)
	var radius = min(grid_size.x, grid_size.y) * 0.3
	
	for y in range(grid_size.y + 1):
		for x in range(grid_size.x + 1):
			var pos = Vector2(x, y)
			var distance = pos.distance_to(center)
			var noise_value = sin(x * 0.2) * cos(y * 0.2) * 0.1
			scalar_field[y * (grid_size.x + 1) + x] = (radius - distance) / radius + noise_value

# Get scalar value at grid position
func get_scalar(x: int, y: int) -> float:
	if x < 0 or x > grid_size.x or y < 0 or y > grid_size.y:
		return 0.0
	return scalar_field[y * (grid_size.x + 1) + x]

# Linear interpolation for smooth contours
func interpolate_vertex(p1: Vector2, p2: Vector2, val1: float, val2: float) -> Vector2:
	if not interpolation or abs(val1 - val2) < 0.001:
		return (p1 + p2) * 0.5
	
	var t = (threshold - val1) / (val2 - val1)
	t = clamp(t, 0.0, 1.0)
	return p1.lerp(p2, t)

# Generate contour lines using marching squares
func generate_contours():
	mesh_data.clear()
	var vertices: PackedVector2Array = []
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell_vertices = process_cell(x, y)
			vertices.append_array(cell_vertices)
	
	mesh_data = vertices
	queue_redraw()

# Process a single cell and return line segments
func process_cell(x: int, y: int) -> PackedVector2Array:
	var vertices: PackedVector2Array = []
	
	# Get corner values
	var corners = [
		get_scalar(x, y), # Bottom-left
		get_scalar(x + 1, y), # Bottom-right
		get_scalar(x + 1, y + 1), # Top-right
		get_scalar(x, y + 1) # Top-left
	]
	
	# Calculate configuration index
	var config = 0
	for i in range(4):
		if corners[i] > threshold:
			config |= (1 << i)
	
	# Skip empty or full cells
	if config == 0 or config == 15:
		return vertices
	
	# Get edge intersections
	var intersections: Array[Vector2] = []
	var edge_mask = EDGE_TABLE[config]
	
	var cell_pos = Vector2(x, y) * cell_size
	var corner_positions = [
		cell_pos, # Bottom-left
		cell_pos + Vector2(cell_size, 0), # Bottom-right
		cell_pos + Vector2(cell_size, cell_size), # Top-right
		cell_pos + Vector2(0, cell_size) # Top-left
	]
	
	# Calculate edge intersections
	for edge in range(4):
		if edge_mask & (1 << edge):
			var start_corner = edge
			var end_corner = (edge + 1) % 4
			
			var start_pos = corner_positions[start_corner]
			var end_pos = corner_positions[end_corner]
			var start_val = corners[start_corner]
			var end_val = corners[end_corner]
			
			var intersection = interpolate_vertex(start_pos, end_pos, start_val, end_val)
			intersections.append(intersection)
	
	# Connect intersections to form line segments
	for i in range(0, intersections.size() - 1, 2):
		vertices.append(intersections[i])
		vertices.append(intersections[i + 1])
	
	return vertices

# Update scalar field with new data
func update_field(new_field: Array[float]):
	if new_field.size() == (grid_size.x + 1) * (grid_size.y + 1):
		scalar_field = new_field
		generate_contours()

# Set threshold and regenerate
func set_threshold(new_threshold: float):
	threshold = new_threshold
	generate_contours()

# Render the contours
func _draw():
	if mesh_data.is_empty():
		return
	
	# Draw contour lines
	for i in range(0, mesh_data.size() - 1, 2):
		draw_line(mesh_data[i], mesh_data[i + 1], Color.WHITE, 2.0)
	
	# Optionally draw grid points for debugging
	if Engine.is_editor_hint():
		for y in range(grid_size.y + 1):
			for x in range(grid_size.x + 1):
				var pos = Vector2(x, y) * cell_size
				var value = get_scalar(x, y)
				var color = Color.RED if value > threshold else Color.BLUE
				draw_circle(pos, 2.0, color)

# Get mesh data as PackedVector2Array for external use
func get_mesh_data() -> PackedVector2Array:
	return mesh_data

# Convert to mesh for 3D rendering or physics
func create_mesh() -> ArrayMesh:
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices_3d: PackedVector3Array = []
	for vertex in mesh_data:
		vertices_3d.append(Vector3(vertex.x, vertex.y, 0))
	
	arrays[Mesh.ARRAY_VERTEX] = vertices_3d
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	
	return array_mesh