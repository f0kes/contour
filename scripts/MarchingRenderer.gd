extends RefCounted
class_name MarchingRenderer

var configurations: Dictionary
var grid_scale: int
var grid_offset_vector: Vector2

# Mesh resources for efficient rendering
var influence_mesh: ArrayMesh
var dots_mesh: ArrayMesh
var lines_mesh: ArrayMesh

func _init(config_dict: Dictionary, scale: int, offset: Vector2):
	configurations = config_dict
	grid_scale = scale
	grid_offset_vector = offset
	
	# Initialize mesh resources
	influence_mesh = ArrayMesh.new()
	dots_mesh = ArrayMesh.new()
	lines_mesh = ArrayMesh.new()

func draw_all(
	node: Node2D, bounds: Dictionary, mip_level: int,
	chunk_manager: ChunkManager, influence_system: InfluenceSystem,
	dot_size: float, dot_color_filled: Color, dot_color_empty: Color,
	line_color: Color, influence_color_positive: Color, influence_color_negative: Color,
	camera_zoom: float = 1.0
):
	# Clear previous meshes
	influence_mesh.clear_surfaces()
	dots_mesh.clear_surfaces()
	lines_mesh.clear_surfaces()
	
	# Build meshes
	build_influence_mesh(bounds, mip_level, influence_system, influence_color_positive, influence_color_negative)
	build_dots_mesh(bounds, mip_level, chunk_manager, dot_size, dot_color_filled, dot_color_empty, camera_zoom)
	build_lines_mesh(bounds, mip_level, chunk_manager, line_color, camera_zoom)
	
	# Render meshes
	render_mesh(node, influence_mesh)
	render_mesh(node, dots_mesh)
	render_mesh(node, lines_mesh)

func build_influence_mesh(
	bounds: Dictionary, mip_level: int,
	influence_system: InfluenceSystem,
	influence_color_positive: Color, influence_color_negative: Color
):
	var vertices: PackedVector2Array = []
	var colors: PackedColorArray = []
	var indices: PackedInt32Array = []
	var vertex_count = 0
	
	for x in range(bounds.min_x, bounds.max_x + 1, mip_level):
		for y in range(bounds.min_y, bounds.max_y + 1, mip_level):
			var influence = influence_system.sample_influence_mipped(x, y, mip_level)
			if abs(influence) > 0.1:
				var color = influence_color_positive if influence > 0 else influence_color_negative
				color.a = clamp(abs(influence) * 0.05, 0.0, 0.3)
				
				var pos = Vector2(x, y) * grid_scale + grid_offset_vector
				var size = Vector2(grid_scale * mip_level, grid_scale * mip_level)
				
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
		
		influence_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func build_dots_mesh(
	bounds: Dictionary, mip_level: int,
	chunk_manager: ChunkManager,
	dot_size: float, dot_color_filled: Color, dot_color_empty: Color, camera_zoom: float = 1.0
):
	var vertices: PackedVector2Array = []
	var colors: PackedColorArray = []
	var indices: PackedInt32Array = []
	var vertex_count = 0
	
	var circle_segments = 12 # Number of segments for circle approximation
	
	for x in range(bounds.min_x, bounds.max_x + 1, mip_level):
		for y in range(bounds.min_y, bounds.max_y + 1, mip_level):
			var value = chunk_manager.get_raw_value_at(x, y, mip_level)
			var color = dot_color_filled if value > 0 else dot_color_empty
			var center = Vector2(x, y) * grid_scale + grid_offset_vector
			var this_dot_size = max(dot_size / camera_zoom * abs(value), 2 / camera_zoom)
			#var this_dot_size = dot_size
			#this_dot_size = min(this_dot_size, 7)
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
		
		dots_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func build_lines_mesh(
	bounds: Dictionary, mip_level: int,
	chunk_manager: ChunkManager, line_color: Color, camera_zoom: float = 1.0
):
	var vertices: PackedVector2Array = []
	var colors: PackedColorArray = []
	var indices: PackedInt32Array = []
	var vertex_count = 0
	
	var line_width = 2.0 / camera_zoom
	
	var mip_bounds = {
		"min_x": bounds.min_x - (bounds.min_x % mip_level),
		"min_y": bounds.min_y - (bounds.min_y % mip_level),
		"max_x": bounds.max_x - (bounds.max_x % mip_level),
		"max_y": bounds.max_y - (bounds.max_y % mip_level)
	}
	
	for x in range(mip_bounds.min_x, mip_bounds.max_x, mip_level):
		for y in range(mip_bounds.min_y, mip_bounds.max_y, mip_level):
			var line_segments = get_marching_square_lines_lerped(x, y, mip_level, chunk_manager)
			
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

func get_marching_square_lines_lerped(x: int, y: int, mip_level: int, chunk_manager: ChunkManager) -> Array:
	var a_val = chunk_manager.get_raw_value_at(x, y, mip_level)
	var b_val = chunk_manager.get_raw_value_at(x + mip_level, y, mip_level)
	var c_val = chunk_manager.get_raw_value_at(x + mip_level, y + mip_level, mip_level)
	var d_val = chunk_manager.get_raw_value_at(x, y + mip_level, mip_level)
	
	# Binary values for configuration
	var a = 1 if a_val > 0 else 0
	var b = 1 if b_val > 0 else 0
	var c = 1 if c_val > 0 else 0
	var d = 1 if d_val > 0 else 0
	
	# Skip uniform cells
	if a == b and b == c and c == d:
		return []
	
	# Corner point positions
	var a_pos = Vector2(x, y) * grid_scale + grid_offset_vector
	var b_pos = Vector2(x + mip_level, y) * grid_scale + grid_offset_vector
	var c_pos = Vector2(x + mip_level, y + mip_level) * grid_scale + grid_offset_vector
	var d_pos = Vector2(x, y + mip_level) * grid_scale + grid_offset_vector
	
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

# Keep legacy drawing methods for compatibility
func draw_influence_background(
	node: Node2D, bounds: Dictionary, mip_level: int,
	influence_system: InfluenceSystem,
	influence_color_positive: Color, influence_color_negative: Color
):
	for x in range(bounds.min_x, bounds.max_x + 1, mip_level):
		for y in range(bounds.min_y, bounds.max_y + 1, mip_level):
			var influence = influence_system.sample_influence_mipped(x, y, mip_level)
			if abs(influence) > 0.1:
				var color = influence_color_positive if influence > 0 else influence_color_negative
				color.a = clamp(abs(influence) * 0.05, 0.0, 0.3)
				
				var rect = Rect2(
					Vector2(x, y) * grid_scale + grid_offset_vector,
					Vector2(grid_scale * mip_level, grid_scale * mip_level)
				)
				node.draw_rect(rect, color)

func draw_grid_dots(
	node: Node2D, bounds: Dictionary, mip_level: int,
	chunk_manager: ChunkManager,
	dot_size: float, dot_color_filled: Color, dot_color_empty: Color
):
	var quantized_dot_size = max(dot_size / mip_level, 1.0)
	
	for x in range(bounds.min_x, bounds.max_x + 1, mip_level):
		for y in range(bounds.min_y, bounds.max_y + 1, mip_level):
			var value = chunk_manager.get_raw_value_at(x, y, mip_level)
			var color = dot_color_filled if value > 0 else dot_color_empty
			var pos = Vector2(x, y) * grid_scale + grid_offset_vector
			dot_size = dot_size * abs(value);
			node.draw_circle(pos, dot_size, color)

func draw_marching_squares(
	node: Node2D, bounds: Dictionary, mip_level: int,
	chunk_manager: ChunkManager, line_color: Color
):
	var quantized_line_width = max(2.0 / mip_level, 1.5)
	var mip_bounds = {
		"min_x": bounds.min_x - (bounds.min_x % mip_level),
		"min_y": bounds.min_y - (bounds.min_y % mip_level),
		"max_x": bounds.max_x - (bounds.max_x % mip_level),
		"max_y": bounds.max_y - (bounds.max_y % mip_level)
	}
	
	for x in range(mip_bounds.min_x, mip_bounds.max_x, mip_level):
		for y in range(mip_bounds.min_y, mip_bounds.max_y, mip_level):
			draw_marching_square_cell_lerped(node, x, y, mip_level, chunk_manager, line_color, 2.0)

func draw_marching_square_cell_lerped(
	node: Node2D, x: int, y: int, mip_level: int,
	chunk_manager: ChunkManager, line_color: Color, line_width: float
):
	# Get actual values instead of just binary 0/1
	var a_val = chunk_manager.get_raw_value_at(x, y, mip_level)
	var b_val = chunk_manager.get_raw_value_at(x + mip_level, y, mip_level)
	var c_val = chunk_manager.get_raw_value_at(x + mip_level, y + mip_level, mip_level)
	var d_val = chunk_manager.get_raw_value_at(x, y + mip_level, mip_level)
	
	# Binary values for configuration
	var a = 1 if a_val > 0 else 0
	var b = 1 if b_val > 0 else 0
	var c = 1 if c_val > 0 else 0
	var d = 1 if d_val > 0 else 0
	
	# Skip uniform cells
	if a == b and b == c and c == d:
		return
	
	# Corner point positions
	var a_pos = Vector2(x, y) * grid_scale + grid_offset_vector
	var b_pos = Vector2(x + mip_level, y) * grid_scale + grid_offset_vector
	var c_pos = Vector2(x + mip_level, y + mip_level) * grid_scale + grid_offset_vector
	var d_pos = Vector2(x, y + mip_level) * grid_scale + grid_offset_vector
	
	# Calculate lerped edge positions
	var e = lerp_edge(a_pos, b_pos, a_val, b_val) # top edge
	var f = lerp_edge(b_pos, c_pos, b_val, c_val) # right edge
	var g = lerp_edge(c_pos, d_pos, c_val, d_val) # bottom edge
	var h = lerp_edge(d_pos, a_pos, d_val, a_val) # left edge
	
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
			
			node.draw_line(point_a_pos, point_b_pos, line_color, line_width, true)

func draw_marching_square_cell(
	node: Node2D, x: int, y: int, mip_level: int,
	chunk_manager: ChunkManager, line_color: Color, line_width: float
):
	# Corner point values
	var a = chunk_manager.get_value_at(x, y, mip_level)
	var b = chunk_manager.get_value_at(x + mip_level, y, mip_level)
	var c = chunk_manager.get_value_at(x + mip_level, y + mip_level, mip_level)
	var d = chunk_manager.get_value_at(x, y + mip_level, mip_level)
	
	# Skip uniform cells
	if a == b and b == c and c == d:
		return
	
	# Corner point positions
	var a_pos = Vector2(x, y) * grid_scale + grid_offset_vector
	var b_pos = Vector2(x + mip_level, y) * grid_scale + grid_offset_vector
	var c_pos = Vector2(x + mip_level, y + mip_level) * grid_scale + grid_offset_vector
	var d_pos = Vector2(x, y + mip_level) * grid_scale + grid_offset_vector
	
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
			
			node.draw_line(point_a_pos, point_b_pos, line_color, line_width, true)
