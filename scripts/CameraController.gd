extends RefCounted
class_name CameraController

var camera: Camera2D
var dragging: bool = false
var drag_start_position: Vector2
var drag_start_camera_position: Vector2
var zoom_factor: float = 1.0
var min_zoom: float = 1.1
var max_zoom: float = 50.0
var previous_mip_level: int = 1
var on_mip_map_change: Callable = Callable()
var zoom_disabled: bool = false

func _init(camera_node: Camera2D, on_mip_map_change: Callable = Callable()):
	camera = camera_node
	previous_mip_level = 1
	self.on_mip_map_change = on_mip_map_change

func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				dragging = true
				drag_start_position = event.position
				drag_start_camera_position = camera.global_position
				return true
			MOUSE_BUTTON_WHEEL_UP:
				if zoom_disabled:
					return false
				zoom_factor = clamp(zoom_factor * 1.2, min_zoom, max_zoom)
				camera.zoom = Vector2(zoom_factor, zoom_factor)
				return true
			MOUSE_BUTTON_WHEEL_DOWN:
				if zoom_disabled:
					return false
				zoom_factor = clamp(zoom_factor / 1.2, min_zoom, max_zoom)
				camera.zoom = Vector2(zoom_factor, zoom_factor)
				return true
	
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = false
			return true
	
	elif event is InputEventMouseMotion and dragging:
		var delta = drag_start_position - event.position
		camera.global_position = drag_start_camera_position + delta / zoom_factor
		return true

	var current_mip_level = get_mip_level()
	if current_mip_level != previous_mip_level:
		previous_mip_level = current_mip_level
		if on_mip_map_change.is_valid():
			on_mip_map_change.call()

	
	return false

func get_mip_level() -> int:
	if zoom_factor > 2.0: return 1
	elif zoom_factor > 1.0: return 1
	elif zoom_factor > 0.5: return 2
	elif zoom_factor > 0.25: return 4
	elif zoom_factor > 0.1: return 8
	elif zoom_factor > 0.05: return 16
	elif zoom_factor > 0.01: return 32
	else: return 64