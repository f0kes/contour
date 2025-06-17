extends Node2D
class_name MarchingSquaresGit

@export var unit_scene: PackedScene

@export var size_x: int = 50
@export var size_y: int = 50
@export var grid_scale: int = 25
@export var dot_size: float = 2.5
@export var grid_offset_vector: Vector2 = Vector2(75, 75)

# Color configuration
@export_group("Colors")
@export var dot_color_filled: Color = Color.RED
@export var dot_color_empty: Color = Color.BLUE
@export var line_color: Color = Color.WHITE
@export var influence_color_positive: Color = Color.RED
@export var influence_color_negative: Color = Color.BLUE

# Systems
var camera_controller: CameraController
var influence_system: InfluenceSystem
var chunk_manager: ChunkManager
var marching_renderer: MarchingRenderer

# Noise configuration
var noise: FastNoiseLite
var noise_offset_vector: Vector2 = Vector2.ZERO

# Painting
var painting: bool = false
var paint_strength: float = 5.0

# Marching squares configurations
const CONFIGURATIONS = {
	0: [], 15: [],
	1: ["e", "h"], 2: ["e", "f"], 4: ["f", "g"], 8: ["g", "h"],
	3: ["h", "f"], 6: ["e", "g"], 12: ["h", "f"], 9: ["e", "g"],
	5: ["h", "e", "g", "f"], 10: ["h", "g", "e", "f"],
	7: ["h", "g"], 14: ["h", "e"], 13: ["e", "f"], 11: ["g", "f"]
}

func _ready() -> void:
	setup_camera()
	setup_noise()
	setup_systems()
	#setup_units()
	update_chunks()

func setup_camera():
	var camera = Camera2D.new()
	add_child(camera)
	camera.enabled = true
	camera_controller = CameraController.new(camera, update_chunks)
	camera.zoom = Vector2(1., 1.2)
	camera.position = Vector2(size_x * grid_scale / 2, size_y * grid_scale / 2)

	camera_controller.zoom_disabled = false

func setup_noise():
	randomize()
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.05

func setup_systems():
	influence_system = InfluenceSystem.new(size_x, size_y, world_to_grid, mark_dirty)
	chunk_manager = ChunkManager.new(noise, noise_offset_vector, influence_system)
	marching_renderer = MarchingRenderer.new(CONFIGURATIONS, grid_scale, grid_offset_vector)

func setup_units():
	for i in range(0, 10):
		spawn_unit(Vector2(randf_range(0, size_x * grid_scale), randf_range(0, size_y * grid_scale)))

func _process(delta: float) -> void:
	influence_system.update(delta)
	paint(delta)
	update_chunks()

func paint(delta: float):
	if painting:
		var world_pos = get_global_mouse_position()
		var grid_pos = world_to_grid(world_pos)
		add_influence(grid_pos, paint_strength)


func spawn_unit(pos: Vector2):
	var unit = unit_scene.instantiate()
	unit.global_position = pos
	add_child(unit)
	influence_system.add_radiant(unit, 10.0, 5.0)

func _input(event):
	# Handle camera input first
	if camera_controller.handle_input(event):
		return
	
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				start_painting(influence_system.influence_strength)
			MOUSE_BUTTON_RIGHT:
				start_painting(-influence_system.influence_strength)
	
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				influence_system.initialize_matrix()
			KEY_1:
				spawn_unit(get_global_mouse_position())
	if painting:
		if event is InputEventMouseButton and not event.pressed:
			painting = false

func start_painting(strength: float):
	paint_strength = strength
	painting = true


func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local_pos = world_pos - grid_offset_vector
	var grid_pos = local_pos / grid_scale
	return Vector2i(int(grid_pos.x), int(grid_pos.y))

func add_influence(center: Vector2i, strength: float):
	var affected_chunks = influence_system.add_influence(center, strength)
	

func mark_dirty(coord: Vector2i):
	var chunk_coord = chunk_manager.world_to_chunk(coord)
	if chunk_coord not in chunk_manager.dirty_chunks:
		chunk_manager.dirty_chunks.append(chunk_coord)
func update_chunks() -> void:
	ensure_visible_chunks_exist()
	update_dirty_chunks()
	queue_redraw()

func ensure_visible_chunks_exist():
	var chunks_needed = get_chunks_in_view()
	var mip_level = camera_controller.get_mip_level()
	var i = 0
	for chunk_coord in chunks_needed:
		if i >= chunk_manager.max_concurrent_chunks:
			break
		i += 1
		var chunk_key = str(chunk_coord) + "_" + str(mip_level)
		if chunk_key not in chunk_manager.chunk_matrix_cache:
			chunk_manager.generate_chunk(chunk_coord, mip_level)

func update_dirty_chunks():
	var mip_level = camera_controller.get_mip_level()
	for chunk_coord in chunk_manager.dirty_chunks:
		chunk_manager.generate_chunk(chunk_coord, mip_level)
	chunk_manager.dirty_chunks.clear()
	queue_redraw()

func get_chunks_in_view() -> Array:
	var bounds = get_visible_grid_bounds(1)
	var mip_level = camera_controller.get_mip_level()
	
	var chunks_needed = []
	var chunk_min = chunk_manager.world_to_chunk(Vector2i(bounds.min_x * mip_level, bounds.min_y * mip_level))
	var chunk_max = chunk_manager.world_to_chunk(Vector2i(bounds.max_x * mip_level, bounds.max_y * mip_level))
	
	for x in range(chunk_min.x, chunk_max.x + 1):
		for y in range(chunk_min.y, chunk_max.y + 1):
			chunks_needed.append(Vector2i(x, y))
	
	return chunks_needed


func get_visible_grid_bounds(padding: int) -> Dictionary:
	var viewport_size = get_viewport().get_visible_rect().size
	var camera = camera_controller.camera
	var camera_pos = camera.global_position
	var mip_level = camera_controller.get_mip_level()
	var zoom = camera.zoom.x

	
	var half_viewport = viewport_size / (2.0 * zoom)
	var world_top_left = camera_pos - half_viewport
	var world_bottom_right = camera_pos + half_viewport
	
	var grid_top_left = world_to_grid(world_top_left)
	var grid_bottom_right = world_to_grid(world_bottom_right)
	
	return {
		"min_x": grid_top_left.x - padding,
		"min_y": grid_top_left.y - padding,
		"max_x": grid_bottom_right.x + padding,
		"max_y": grid_bottom_right.y + padding
	}

func _draw() -> void:
	var mip_level = camera_controller.get_mip_level()
	var bounds = get_visible_grid_bounds(2)
	var camera_zoom = camera_controller.zoom_factor
	marching_renderer.draw_all(
		self, bounds, mip_level,
		chunk_manager, influence_system,
		dot_size, dot_color_filled, dot_color_empty,
		line_color, influence_color_positive, influence_color_negative, camera_zoom
	)

# Public interface
func increment_noise_offset():
	noise_offset_vector += Vector2(1, 1)

func set_size(new_size_x: int, new_size_y: int):
	size_x = new_size_x
	size_y = new_size_y
	influence_system = InfluenceSystem.new(size_x, size_y, world_to_grid, mark_dirty)
	update_chunks()

func get_zoom_info() -> String:
	return "Zoom: %.2f, Mip Level: %d" % [camera_controller.zoom_factor, camera_controller.get_mip_level()]
