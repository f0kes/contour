extends Panel
class_name MSControlPanel
@onready var offset_move_timer: Timer = get_parent().get_parent().get_node("OffsetMoveTimer")
@onready var marching_square: MarchingSquares = get_parent().get_parent()

var offset_move_timer_is_running: bool = true

@onready var speed_slider: HSlider = $VBoxContainer/SpeedContainer/SpeedSlider
@onready var animate_check: CheckButton = $VBoxContainer/AnimateCheckButton
@onready var size_x_slider: HSlider = $VBoxContainer/SizeXContainer/SizeXSlider
@onready var size_y_slider: HSlider = $VBoxContainer/SizeYContainer/SizeYSlider
@onready var influence_strength_slider: HSlider = $VBoxContainer/InfluenceContainer/InfluenceSlider
@onready var influence_radius_slider: HSlider = $VBoxContainer/RadiusContainer/RadiusSlider
@onready var zoom_label: Label = $VBoxContainer/ZoomLabel
@onready var reset_button: Button = $VBoxContainer/ResetButton

func _ready():
    offset_move_timer.start()
    
    # Connect signals
    speed_slider.value_changed.connect(_on_speed_slider_value_changed)
    animate_check.toggled.connect(_on_animate_check_button_toggled)
    size_x_slider.value_changed.connect(_on_size_x_slider_value_changed)
    size_y_slider.value_changed.connect(_on_size_y_slider_value_changed)
    influence_strength_slider.value_changed.connect(_on_influence_strength_slider_value_changed)
    influence_radius_slider.value_changed.connect(_on_influence_radius_slider_value_changed)
    reset_button.pressed.connect(_on_reset_button_pressed)
    
    # Set initial values
    speed_slider.value = offset_move_timer.wait_time
    size_x_slider.value = marching_square.size_x
    size_y_slider.value = marching_square.size_y
    influence_strength_slider.value = marching_square.influence_strength
    influence_radius_slider.value = marching_square.influence_radius

func _process(_delta):
    # Update zoom info
    if marching_square:
        zoom_label.text = marching_square.get_zoom_info()

func increment_noise_offset() -> void:
    marching_square.increment_noise_offset()

func _on_offset_move_timer_timeout() -> void:
    increment_noise_offset()
    marching_square.update_values()

func _on_speed_slider_value_changed(value: float) -> void:
    offset_move_timer.wait_time = clamp(value, 0.01, 2.0)
    
    if offset_move_timer_is_running:
        offset_move_timer.start()

func _on_animate_check_button_toggled(button_pressed: bool) -> void:
    offset_move_timer_is_running = button_pressed
    if offset_move_timer_is_running:
        offset_move_timer.start()
    else:
        offset_move_timer.stop()

func _on_size_x_slider_value_changed(value: float) -> void:
    var new_size_x = int(clamp(value, 4, 200))
    marching_square.set_size(new_size_x, marching_square.size_y)

func _on_size_y_slider_value_changed(value: float) -> void:
    var new_size_y = int(clamp(value, 4, 200))
    marching_square.set_size(marching_square.size_x, new_size_y)

func _on_influence_strength_slider_value_changed(value: float) -> void:
    marching_square.influence_strength = value

func _on_influence_radius_slider_value_changed(value: float) -> void:
    marching_square.influence_radius = int(value)

func _on_reset_button_pressed() -> void:
    marching_square.reset_influence()