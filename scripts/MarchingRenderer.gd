extends RefCounted
class_name MarchingRenderer

var configurations: Dictionary
var grid_scale: int
var grid_offset_vector: Vector2

func _init(config_dict: Dictionary, scale: int, offset: Vector2):
	configurations = config_dict
	grid_scale = scale
	grid_offset_vector = offset

func draw_all(
	node: Node2D, bounds: Dictionary, mip_level: int,
	chunk_manager: ChunkManager, influence_system: InfluenceSystem,
	dot_size: float, dot_color_filled: Color, dot_color_empty: Color,
	line_color: Color, influence_color_positive: Color, influence_color_negative: Color
):
	draw_influence_background(node, bounds, mip_level, influence_system, influence_color_positive, influence_color_negative)
	draw_grid_dots(node, bounds, mip_level, chunk_manager, dot_size, dot_color_filled, dot_color_empty)
	draw_marching_squares(node, bounds, mip_level, chunk_manager, line_color)

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
			var value = chunk_manager.get_value_at(x, y, mip_level)
			var color = dot_color_filled if value == 1 else dot_color_empty
			var pos = Vector2(x, y) * grid_scale + grid_offset_vector
			
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

# New function with lerping
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
	var e = lerp_edge(a_pos, b_pos, a_val, b_val)  # top edge
	var f = lerp_edge(b_pos, c_pos, b_val, c_val)  # right edge
	var g = lerp_edge(c_pos, d_pos, c_val, d_val)  # bottom edge
	var h = lerp_edge(d_pos, a_pos, d_val, a_val)  # left edge
	
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

# Helper function to interpolate edge positions
func lerp_edge(pos1: Vector2, pos2: Vector2, val1: float, val2: float) -> Vector2:
	# If values have the same sign, no interpolation needed
	if (val1 > 0) == (val2 > 0):
		return (pos1 + pos2) / 2
	
	# Calculate interpolation factor based on where the zero-crossing occurs
	var t = abs(val1) / (abs(val1) + abs(val2))
	return pos1.lerp(pos2, t)

# Keep the old function for compatibility
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