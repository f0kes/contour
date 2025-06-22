extends Control
class_name HotbarSlot

signal slot_pressed

var is_selected: bool = false
var hotkey_number: int = 1

@onready var background: Panel
@onready var icon: TextureRect
@onready var count_label: Label
@onready var hotkey_label: Label
@onready var button: Button

func _init():
	custom_minimum_size = Vector2(60, 60)
	create_components()

func create_components():
	# Background panel
	background = Panel.new()
	background.anchors_preset = Control.PRESET_FULL_RECT
	add_child(background)
	
	# Main container
	var vbox = VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.offset_left = 5
	vbox.offset_top = 5
	vbox.offset_right = -5
	vbox.offset_bottom = -5
	add_child(vbox)
	
	# Icon
	icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	vbox.add_child(icon)
	
	# Count label
	count_label = Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 10)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(count_label)
	
	# Hotkey label (bottom right corner)
	hotkey_label = Label.new()
	hotkey_label.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	hotkey_label.offset_left = -15
	hotkey_label.offset_top = -15
	hotkey_label.add_theme_font_size_override("font_size", 8)
	hotkey_label.add_theme_color_override("font_color", Color.YELLOW)
	add_child(hotkey_label)
	
	# Invisible button for clicks
	button = Button.new()
	button.flat = true
	button.anchors_preset = Control.PRESET_FULL_RECT
	button.pressed.connect(_on_button_pressed)
	add_child(button)
	
	update_style()

func setup(p_hotkey_number: int):
	hotkey_number = p_hotkey_number
	hotkey_label.text = str(hotkey_number)

func _on_button_pressed():
	slot_pressed.emit()

func set_selected(selected: bool):
	is_selected = selected
	update_style()

func update_style():
	if not background:
		return
		
	var style = StyleBoxFlat.new()
	if is_selected:
		style.bg_color = Color(0.4, 0.6, 1.0, 0.8) # Blue
		style.border_color = Color.YELLOW
	else:
		style.bg_color = Color(0.2, 0.2, 0.2, 0.8) # Gray
		style.border_color = Color(0.5, 0.5, 0.5, 1.0)
	
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	
	background.add_theme_stylebox_override("panel", style)

func update_display(building_data: BuildingData, count: int):
	if building_data.icon:
		icon.texture = building_data.icon
	else:
		icon.texture = null
	
	count_label.text = str(count)
	
	# Gray out if no buildings available
	modulate = Color.WHITE if count > 0 else Color(0.5, 0.5, 0.5, 1.0)
