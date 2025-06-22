extends RefCounted
class_name MarchingRenderer

var configurations: Dictionary
var grid_scale: int
var grid_offset_vector: Vector2

# Mesh resources for efficient rendering - per fraction
var influence_meshes: Dictionary = {} # FractionType -> ArrayMesh
var dots_meshes: Dictionary = {} # FractionType -> ArrayMesh
var lines_mesh: ArrayMesh
var country_meshes: Dictionary = {} # FractionType -> ArrayMesh

var fraction_system: FractionSystem

func _init(config_dict: Dictionary, scale: int, offset: Vector2, p_fraction_system: FractionSystem):
	fraction_system = p_fraction_system
	configurations = config_dict
	grid_scale = scale
	grid_offset_vector = offset
	
	# Initialize mesh resources for each fraction
	for fraction in FractionSystem.FractionType.values():
		if fraction != FractionSystem.FractionType.NONE:
			influence_meshes[fraction] = ArrayMesh.new()
			dots_meshes[fraction] = ArrayMesh.new()
			country_meshes[fraction] = ArrayMesh.new()
	
	lines_mesh = ArrayMesh.new()

func draw_all(
	node: Node2D, viewport: Viewport, camera: Camera2D, mip_level: int,
	influence_map: InfluenceMap,
	dot_size: float, line_color: Color,
	camera_zoom: float = 1.0,
	padding: int = 1
):
	# Clear previous meshes
	for fraction in influence_meshes:
		influence_meshes[fraction].clear_surfaces()
		dots_meshes[fraction].clear_surfaces()
		country_meshes[fraction].clear_surfaces()
	lines_mesh.clear_surfaces()
	
	# Get the mip-mapped grid
	var grid_data = influence_map.get_mip_mapped_grid(viewport, camera, mip_level, padding)
	var matrix = grid_data.matrix
	var converter = grid_data.converter
	
	# Build meshes per fraction
	for fraction in influence_meshes:
		var fraction_color = fraction_system.get_fraction_color(fraction)
		build_influence_mesh_for_fraction(matrix, converter, fraction, fraction_color)
		build_dots_mesh_for_fraction(matrix, converter, fraction, fraction_color, dot_size, camera_zoom)
		build_country_mesh_for_fraction(matrix, converter, fraction, fraction_color)
	
	build_lines_mesh(matrix, converter, line_color, camera_zoom)
	
	# Render meshes
	for fraction in influence_meshes:
		render_mesh(node, influence_meshes[fraction])
		render_mesh(node, dots_meshes[fraction])
		render_mesh(node, country_meshes[fraction])
	render_mesh(node, lines_mesh)

func build_country_mesh_for_fraction(
	matrix: Array, converter: Callable,
	fraction: FractionSystem.FractionType,
	base_color: Color
):
	var vertices: PackedVector2Array = []
	var colors: PackedColorArray = []
	var indices: PackedInt32Array = []
	var vertex_count = 0
	
	var width = matrix.size()
	if width == 0:
		return
	var height = matrix[0].size()
	
	# Process each 2x2 cell for marching squares
	for x in range(width - 1):
		for y in range(height - 1):
			# Get the 2x2 cell values for this fraction
			var a_influences = matrix[x][y]
			var b_influences = matrix[x + 1][y]
			var c_influences = matrix[x + 1][y + 1]
			var d_influences = matrix[x][y + 1]
			
			var a_val = a_influences.get(fraction, 0.0)
			var b_val = b_influences.get(fraction, 0.0)
			var c_val = c_influences.get(fraction, 0.0)
			var d_val = d_influences.get(fraction, 0.0)
			
			# Binary values for configuration (threshold for "filled")
			var threshold = 0.1
			var a = 1 if a_val > threshold else 0
			var b = 1 if b_val > threshold else 0
			var c = 1 if c_val > threshold else 0
			var d = 1 if d_val > threshold else 0
			
			# Skip completely empty cells
			if a + b + c + d == 0:
				continue
			
			# Calculate configuration
			var configuration = a + b * 2 + c * 4 + d * 8
			
			# Get corner positions
			var a_pos = converter.call(x, y)
			var b_pos = converter.call(x + 1, y)
			var c_pos = converter.call(x + 1, y + 1)
			var d_pos = converter.call(x, y + 1)
			
			# Calculate lerped edge positions
			var e = lerp_edge(a_pos, b_pos, a_val, b_val) # top edge
			var f = lerp_edge(b_pos, c_pos, b_val, c_val) # right edge
			var g = lerp_edge(c_pos, d_pos, c_val, d_val) # bottom edge
			var h = lerp_edge(d_pos, a_pos, d_val, a_val) # left edge
			
			# Create filled polygons based on configuration
			var polygons = get_marching_square_polygons(configuration, a_pos, b_pos, c_pos, d_pos, e, f, g, h)
			
			for polygon in polygons:
				if polygon.size() >= 3:
					# Triangulate the polygon (simple fan triangulation)
					var base_vertex = vertex_count
					
					# Add all vertices
					for vertex in polygon:
						vertices.append(vertex)
						colors.append(base_color)
						vertex_count += 1
					
					# Create triangles using fan triangulation
					for i in range(1, polygon.size() - 1):
						indices.append(base_vertex)
						indices.append(base_vertex + i)
						indices.append(base_vertex + i + 1)
	
	if vertices.size() > 0:
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		
		country_meshes[fraction].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func build_influence_mesh_for_fraction(
	matrix: Array, converter: Callable,
	fraction: FractionSystem.FractionType,
	base_color: Color
):
	var vertices: PackedVector2Array = []
	var colors: PackedColorArray = []
	var indices: PackedInt32Array = []
	var vertex_count = 0
	
	var width = matrix.size()
	if width == 0:
		return
	var height = matrix[0].size()
	
	for x in range(width):
		for y in range(height):
			var influences = matrix[x][y]
			var influence = influences.get(fraction, 0.0)
			
			if influence > 0.1:
				var color = base_color
				color.a = clamp(influence * 0.3, 0.0, 0.6)
				
				var pos = converter.call(x, y)
				var size = Vector2(grid_scale, grid_scale)
				
				# Create quad vertices
				vertices.append(pos)
				vertices.append(Vector2(pos.x + size.x, pos.y))
				vertices.append(Vector2(pos.x + size.x, pos.y + size.y))
				vertices.append(Vector2(pos.x, pos.y + size.y))
				
				# Add colors for each vertex
				for i in range(4):
					colors.append(color)
				
				# Create triangles (two per quad)
				indices.append(vertex_count)
				indices.append(vertex_count + 1)
				indices.append(vertex_count + 2)
				
				indices.append(vertex_count)
				indices.append(vertex_count + 2)
				indices.append(vertex_count + 3)
				
				vertex_count += 4
	
	if vertices.size() > 0:
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		
		influence_meshes[fraction].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func build_dots_mesh_for_fraction(
	matrix: Array, converter: Callable,
	fraction: FractionSystem.FractionType,
	base_color: Color, dot_size: float, camera_zoom: float = 1.0
):
	var vertices: PackedVector2Array = []
	var colors: PackedColorArray = []
	var indices: PackedInt32Array = []
	var vertex_count = 0
	
	var circle_segments = 12
	var width = matrix.size()
	if width == 0:
		return
	var height = matrix[0].size()
	
	for x in range(width):
		for y in range(height):
			var influences = matrix[x][y]
			
			# Check if this fraction is dominant
			var max_influence = 0.0
			var dominant_fraction = FractionSystem.FractionType.NONE
			
			for f in influences:
				if influences[f] > max_influence:
					max_influence = influences[f]
					dominant_fraction = f
			
			# Only draw dot if this fraction is dominant
			if dominant_fraction == fraction and max_influence > 0.1:
				var color = base_color
				var center = converter.call(x, y)
				var this_dot_size = max(dot_size / camera_zoom, 2 / camera_zoom)
				
				# Scale dot size by influence strength
				this_dot_size *= clamp(max_influence, 0.3, 1.0)
				
				# Create circle vertices
				var center_index = vertex_count
				vertices.append(center)
				colors.append(color)
				vertex_count += 1
				
				# Create circle perimeter points
				for i in range(circle_segments):
					var angle = i * 2.0 * PI / circle_segments
					var point = center + Vector2(cos(angle), sin(angle)) * this_dot_size
					vertices.append(point)
					colors.append(color)
					vertex_count += 1
				
				# Create triangles for the circle
				for i in range(circle_segments):
					var next_i = (i + 1) % circle_segments
					indices.append(center_index)
					indices.append(center_index + 1 + i)
					indices.append(center_index + 1 + next_i)
	
	if vertices.size() > 0:
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		
		dots_meshes[fraction].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func build_lines_mesh(
	matrix: Array, converter: Callable,
	line_color: Color, camera_zoom: float = 1.0
):
	var vertices: PackedVector2Array = []
	var colors: PackedColorArray = []
	var indices: PackedInt32Array = []
	var vertex_count = 0
	
	var line_width = 2.0 / camera_zoom
	var width = matrix.size()
	if width == 0:
		return
	var height = matrix[0].size()
	
	# Process each 2x2 cell for marching squares
	for x in range(width - 1):
		for y in range(height - 1):
			var line_segments = get_marching_square_lines_from_matrix(matrix, x, y, converter)
			
			for segment in line_segments:
				var start_pos = segment.start
				var end_pos = segment.end
				
				# Create thick line as quad
				var direction = (end_pos - start_pos).normalized()
				var perpendicular = Vector2(-direction.y, direction.x) * line_width * 0.5
				
				# Quad vertices
				vertices.append(start_pos + perpendicular)
				vertices.append(start_pos - perpendicular)
				vertices.append(end_pos - perpendicular)
				vertices.append(end_pos + perpendicular)
				
				# Add colors
				for i in range(4):
					colors.append(line_color)
				
				# Create triangles
				indices.append(vertex_count)
				indices.append(vertex_count + 1)
				indices.append(vertex_count + 2)
				
				indices.append(vertex_count)
				indices.append(vertex_count + 2)
				indices.append(vertex_count + 3)
				
				vertex_count += 4
	
	if vertices.size() > 0:
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		
		lines_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func get_marching_square_lines_from_matrix(matrix: Array, x: int, y: int, converter: Callable) -> Array:
	# Get net influence values for the 2x2 cell
	var a_influences = matrix[x][y]
	var b_influences = matrix[x + 1][y]
	var c_influences = matrix[x + 1][y + 1]
	var d_influences = matrix[x][y + 1]
	
	# Calculate net influence (dominant - others)
	var a_val = calculate_net_influence(a_influences)
	var b_val = calculate_net_influence(b_influences)
	var c_val = calculate_net_influence(c_influences)
	var d_val = calculate_net_influence(d_influences)
	
	# Binary values for configuration
	var a = 1 if a_val > 0 else 0
	var b = 1 if b_val > 0 else 0
	var c = 1 if c_val > 0 else 0
	var d = 1 if d_val > 0 else 0
	
	# Skip uniform cells
	if a == b and b == c and c == d:
		return []
	
	# Corner point positions
	var a_pos = converter.call(x, y)
	var b_pos = converter.call(x + 1, y)
	var c_pos = converter.call(x + 1, y + 1)
	var d_pos = converter.call(x, y + 1)
	
	# Calculate lerped edge positions
	var e = lerp_edge(a_pos, b_pos, a_val, b_val) # top edge
	var f = lerp_edge(b_pos, c_pos, b_val, c_val) # right edge
	var g = lerp_edge(c_pos, d_pos, c_val, d_val) # bottom edge
	var h = lerp_edge(d_pos, a_pos, d_val, a_val) # left edge
	
	var edge_points = {"e": e, "f": f, "g": g, "h": h}
	
	# Calculate configuration
	var configuration = a + b * 2 + c * 4 + d * 8
	var points_to_connect = configurations.get(configuration, [])
	
	# Create line segments
	var segments = []
	for i in range(0, points_to_connect.size(), 2):
		if i + 1 < points_to_connect.size():
			var point_a = points_to_connect[i]
			var point_b = points_to_connect[i + 1]
			
			var segment = {
				"start": edge_points[point_a],
				"end": edge_points[point_b]
			}
			segments.append(segment)
	
	return segments

func get_marching_square_polygons(configuration: int, a_pos: Vector2, b_pos: Vector2, c_pos: Vector2, d_pos: Vector2, e: Vector2, f: Vector2, g: Vector2, h: Vector2) -> Array:
	# Returns arrays of Vector2 points that form polygons for filled marching squares
	match configuration:
		0: return [] # No fill
		1: return [[a_pos, e, h]] # Corner A
		2: return [[b_pos, f, e]] # Corner B
		3: return [[a_pos, b_pos, f, h]] # Side AB
		4: return [[c_pos, g, f]] # Corner C
		5: return [[a_pos, e, f, g, h]] # Diagonal AC
		6: return [[b_pos, c_pos, g, e]] # Side BC
		7: return [[a_pos, b_pos, c_pos, g, h]] # Three corners ABC
		8: return [[d_pos, h, g]] # Corner D
		9: return [[a_pos, e, g, d_pos]] # Side AD
		10: return [[b_pos, f, h, d_pos], [h, f, g]] # Diagonal BD (two polygons)
		11: return [[a_pos, b_pos, f, g, d_pos]] # Three corners ABD
		12: return [[c_pos, d_pos, h, f]] # Side CD
		13: return [[a_pos, e, f, c_pos, d_pos]] # Three corners ACD
		14: return [[b_pos, c_pos, d_pos, h, e]] # Three corners BCD
		15: return [[a_pos, b_pos, c_pos, d_pos]] # Full square
		_: return []

func calculate_net_influence(influences: Dictionary) -> float:
	if influences.is_empty():
		return 0.0
	
	# Find the strongest influence
	var max_influence = 0.0
	var dominant_fraction = FractionSystem.FractionType.NONE
	
	for fraction in influences:
		var influence = influences[fraction]
		if influence > max_influence:
			max_influence = influence
			dominant_fraction = fraction
	
	if dominant_fraction == FractionSystem.FractionType.NONE:
		return 0.0
	
	# Calculate sum of opposing influences
	var opposing_sum = 0.0
	for fraction in influences:
		if fraction != dominant_fraction:
			opposing_sum += influences[fraction]
	
	# Net influence = max(0, dominant - sum(others))
	return max(0.0, max_influence - opposing_sum)

func render_mesh(node: Node2D, mesh: ArrayMesh):
	if mesh.get_surface_count() > 0:
		# Use CanvasItem's draw_mesh method if available, otherwise fall back to manual rendering
		if node.has_method("draw_mesh"):
			node.draw_mesh(mesh, null, Transform2D.IDENTITY)
		else:
			# Fallback: render mesh manually using draw_polygon for each surface
			for surface_idx in range(mesh.get_surface_count()):
				var arrays = mesh.surface_get_arrays(surface_idx)
				var vertices = arrays[Mesh.ARRAY_VERTEX]
				var colors = arrays[Mesh.ARRAY_COLOR]
				var indices = arrays[Mesh.ARRAY_INDEX]
				
				if indices and indices.size() > 0:
					# Draw triangles
					for i in range(0, indices.size(), 3):
						if i + 2 < indices.size():
							var triangle_vertices = PackedVector2Array()
							var triangle_colors = PackedColorArray()
							
							for j in range(3):
								var idx = indices[i + j]
								triangle_vertices.append(vertices[idx])
								triangle_colors.append(colors[idx])
							
							node.draw_colored_polygon(triangle_vertices, triangle_colors)

# Helper function to interpolate edge positions
func lerp_edge(pos1: Vector2, pos2: Vector2, val1: float, val2: float) -> Vector2:
	# If values have the same sign, no interpolation needed
	if (val1 > 0) == (val2 > 0):
		return (pos1 + pos2) / 2
	
	# Calculate interpolation factor based on where the zero-crossing occurs
	var t = abs(val1) / (abs(val1) + abs(val2))
	return pos1.lerp(pos2, t)