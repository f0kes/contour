extends Control
class_name MyHotbar

signal building_selected(building_type: BuildingSystem.BuildingType)

var building_system: BuildingSystem
var hotbar_slots: Array[HotbarSlot] = []
var selected_slot: int = -1

@onready var hotbar_container: HBoxContainer = $HotbarContainer

# Building types for each slot
var slot_building_types: Array[BuildingSystem.BuildingType] = [
	BuildingSystem.BuildingType.FACTORY,
	BuildingSystem.BuildingType.HOUSE,
	BuildingSystem.BuildingType.UNIVERSITY,
	BuildingSystem.BuildingType.MINE,
	BuildingSystem.BuildingType.OIL
]

func _ready():
	setup_hotbar_slots()

func initialize(p_building_system: BuildingSystem):
	building_system = p_building_system
	update_hotbar_display()

func setup_hotbar_slots():
	for i in range(slot_building_types.size()):
		var slot = HotbarSlot.new()
		slot.setup(i + 1) # Hotkey number
		slot.slot_pressed.connect(_on_slot_pressed.bind(i))
		hotbar_container.add_child(slot)
		hotbar_slots.append(slot)

func _on_slot_pressed(slot_index: int):
	select_slot(slot_index)

func select_slot(slot_index: int):
	if slot_index < 0 or slot_index >= hotbar_slots.size():
		return
	
	# Update visual selection
	for i in range(hotbar_slots.size()):
		hotbar_slots[i].set_selected(i == slot_index)
	
	selected_slot = slot_index
	
	# Select building type
	var building_type = slot_building_types[slot_index]
	building_system.select_building(building_type)
	building_selected.emit(building_type)

func update_hotbar_display():
	if not building_system:
		return
	
	for i in range(hotbar_slots.size()):
		var slot = hotbar_slots[i]
		var building_type = slot_building_types[i]
		var building_data = building_system.get_building_data(building_type)
		var count = building_system.get_building_count(building_type)
		
		if building_data:
			slot.update_display(building_data, count)

func _input(event):
	if event is InputEventKey and event.pressed:
		# Handle hotkey selection (1-5)
		var key_code = event.keycode
		if key_code >= KEY_1 and key_code <= KEY_5:
			var slot_index = key_code - KEY_1
			if slot_index < hotbar_slots.size():
				select_slot(slot_index)
