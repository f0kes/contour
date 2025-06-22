extends Node2D
class_name MarchingSquaresGit

@export var unit_scene: PackedScene
@export var hotbar_scene: PackedScene
@export var building_definitions: BuildingDefinitions

@export var size_x: int = 50
@export var size_y: int = 50
@export var grid_scale: int = 25
@export var dot_size: float = 2.5
@export var grid_offset_vector: Vector2 = Vector2(75, 75)

@export var player_fraction: FractionSystem.FractionType = FractionSystem.FractionType.RED


# Color configuration
@export_group("Colors")
@export var dot_color_filled: Color = Color.RED
@export var dot_color_empty: Color = Color.BLUE
@export var line_color: Color = Color.WHITE

@export var paint_strength: float = 5.0


# Systems
var influence_map: InfluenceMap
var paint_system: PaintSystem
var radiant_system: RadiantSystem

var fraction_system: FractionSystem
var camera_controller: CameraController


var marching_renderer: MarchingRenderer

var canvas_layer: CanvasLayer
var hotbar: MyHotbar

var building_system: BuildingSystem
var building_mode: bool = false


# Noise configuration
var noise: FastNoiseLite
var noise_offset_vector: Vector2 = Vector2.ZERO

# Painting
var painting: bool = false

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
	setup_ui()
	#setup_units()
	#update_chunks()

func setup_camera():
	var camera = Camera2D.new()
	add_child(camera)
	camera.enabled = true
	camera_controller = CameraController.new(camera, update_chunks)
	camera.zoom = Vector2(1., 1.2)
	#camera.position = Vector2(size_x * grid_scale / 2, size_y * grid_scale / 2)

	camera_controller.zoom_disabled = false

func setup_noise():
	randomize()
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.05

func setup_systems():
	influence_map = InfluenceMap.new()

	fraction_system = FractionSystem.new() # TODO: Pass fraction data from here, instead of initializing there
	paint_system = PaintSystem.new(influence_map)
	radiant_system = RadiantSystem.new(influence_map)
	
	influence_map.initialize_with_multi_faction_noise(size_x, size_y, fraction_system.fraction_colors.keys())
	
	marching_renderer = MarchingRenderer.new(CONFIGURATIONS, grid_scale, grid_offset_vector, fraction_system)
	building_system = BuildingSystem.new(influence_map, radiant_system, self, building_definitions)
	
	
func setup_ui():
	canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	setup_hotbar_ui()


func setup_hotbar_ui():
	hotbar = hotbar_scene.instantiate()
	canvas_layer.add_child(hotbar)
	hotbar.initialize(building_system)
	hotbar.building_selected.connect(_on_building_selected)


func _on_building_selected(building_type: BuildingSystem.BuildingType):
	building_mode = true
	print("Selected building: ", building_definitions.get_building_data(building_type).building_name)


func setup_units():
	for i in range(0, 10):
		spawn_unit(Vector2(randf_range(0, size_x * grid_scale), randf_range(0, size_y * grid_scale)))

func _process(delta: float) -> void:
	#TODO: Add radiant system update
	paint(delta)
	update_chunks()

func paint(delta: float):
	if painting:
		var world_pos = get_global_mouse_position()
		var grid_pos = world_to_grid(world_pos)
		paint_influence(grid_pos, paint_strength)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x, grid_pos.y) * grid_scale + grid_offset_vector

func spawn_unit(pos: Vector2):
	var unit = unit_scene.instantiate()
	unit.global_position = pos
	add_child(unit)
	#todo: process radiant

func _input(event):
	# Handle camera input first
	if camera_controller.handle_input(event):
		return
	
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if building_mode:
					try_place_building()
				else:
					start_painting(paint_strength)
			MOUSE_BUTTON_RIGHT:
				if building_mode:
					building_mode = false
				else:
					start_painting(-paint_strength)
				
	
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				spawn_unit(get_global_mouse_position())
	if painting:
		if event is InputEventMouseButton and not event.pressed:
			painting = false

func try_place_building():
	var world_pos = get_global_mouse_position()
	
	if building_system.place_building(building_system.selected_building_type, world_pos, player_fraction):
		print("Building placed successfully!")
		hotbar.update_hotbar_display()
	else:
		print("Cannot place building here!")

func start_painting(strength: float):
	paint_strength = strength
	painting = true


func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local_pos = world_pos - grid_offset_vector
	var grid_pos = local_pos / grid_scale
	return Vector2i(int(grid_pos.x), int(grid_pos.y))

func paint_influence(center: Vector2i, strength: float):
	var _affected_chunks = paint_system.paint_influence(center, strength)

	
func update_chunks() -> void:
	#update_dirty_chunks()
	queue_redraw()

# func ensure_visible_chunks_exist():
# 	var chunks_needed = get_chunks_in_view()
# 	var mip_level = camera_controller.get_mip_level()
# 	var i = 0
# 	for chunk_coord in chunks_needed:
# 		if i >= chunk_manager.max_concurrent_chunks:
# 			break
# 		i += 1
# 		var chunk_key = str(chunk_coord) + "_" + str(mip_level)
# 		if chunk_key not in chunk_manager.chunk_matrix_cache:
# 			chunk_manager.generate_chunk(chunk_coord, mip_level)

# func update_dirty_chunks():
# 	var mip_level = camera_controller.get_mip_level()
# 	for chunk_coord in chunk_manager.dirty_chunks:
# 		chunk_manager.generate_chunk(chunk_coord, mip_level)
# 	chunk_manager.dirty_chunks.clear()
# 	queue_redraw()


func _draw() -> void:
	var mip_level = camera_controller.get_mip_level()
	var bounds = influence_map.get_visible_grid_bounds(2, get_viewport(), camera_controller.camera, grid_scale)
	var camera_zoom = camera_controller.zoom_factor
	marching_renderer.draw_all(
		self, get_viewport(), camera_controller.camera, mip_level,
		influence_map,
		dot_size,
		line_color, camera_zoom
	)
	if building_mode:
		draw_building_preview()


func draw_building_preview():
	var world_pos = get_global_mouse_position()
	var building_def = building_system.get_selected_building_data()
	
	# Check if can place
	var can_place = building_system.can_place_building(building_system.selected_building_type, world_pos, player_fraction)
	var color = Color.GREEN if can_place else Color.RED
	color.a = 0.5
	
	# Draw building preview circle
	draw_circle(world_pos, building_def.influence_radius * grid_scale, color)
	
	# Draw building icon/placeholder
	draw_circle(world_pos, 10, Color.WHITE)
# Public interface
func increment_noise_offset():
	noise_offset_vector += Vector2(1, 1)


func get_zoom_info() -> String:
	return "Zoom: %.2f, Mip Level: %d" % [camera_controller.zoom_factor, camera_controller.get_mip_level()]
