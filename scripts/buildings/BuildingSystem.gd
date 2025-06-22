extends RefCounted
class_name BuildingSystem

enum BuildingType {
	
	FACTORY,
	HOUSE,
	UNIVERSITY,
	MINE,
	OIL,
}

class PlacedBuilding:
	var building_data: BuildingData
	var position: Vector2
	var radiant_id: int
	var building_node: Node2D
	
	func _init(p_building_data: BuildingData, p_position: Vector2, p_radiant_id: int = -1, p_building_node: Node2D = null):
		building_data = p_building_data
		position = p_position
		radiant_id = p_radiant_id
		building_node = p_building_node

@export var building_definitions: BuildingDefinitions
@export var building_scale: float = 150
var inventory: Dictionary = {} # BuildingType -> int (count)
var placed_buildings: Array[PlacedBuilding] = []
var selected_building_type: BuildingType = BuildingType.HOUSE

var influnce_map: InfluenceMap
var radiant_system: RadiantSystem

# References to other systems

var parent_node: Node2D # For spawning building nodes

var occupation_set: Dictionary[Vector2i, bool] = {}
var occupation_chunk: float = 300
var occupation_radius: float = 150

func _init(p_influence_map: InfluenceMap, p_radiant_system: RadiantSystem, p_parent_node: Node2D, p_building_definitions: BuildingDefinitions):
	influnce_map = p_influence_map
	radiant_system = p_radiant_system
	parent_node = p_parent_node
	building_definitions = p_building_definitions
	initialize_inventory()

func initialize_inventory():
	inventory[BuildingType.HOUSE] = 5
	inventory[BuildingType.FACTORY] = 3
	inventory[BuildingType.UNIVERSITY] = 8
	inventory[BuildingType.MINE] = 15
	inventory[BuildingType.OIL] = 1

func can_place_building(building_type: BuildingType, world_position: Vector2, fraction: FractionSystem.FractionType) -> bool:
	# Check if we have the building in inventory
	if not inventory.has(building_type) or inventory[building_type] <= 0:
		return false
	
	# Check if position is on controlled land (positive influence)
	var grid_pos = influnce_map.world_to_grid(world_position.x, world_position.y)
	var influence = influnce_map.get_faction_dominance(grid_pos.x, grid_pos.y, fraction, 0)
	if influence <= 0:
		return false
	
	# Check if there's already a building too close
	var building_data = building_definitions.get_building_data(building_type)
	if not building_data:
		return false
	
	for building in placed_buildings:
		if building.position.distance_to(world_position) < occupation_radius:
			return false
		
	
	return true

func get_occupation_place(pos: Vector2) -> Vector2i:
	return Vector2i(floor(pos.x / occupation_chunk), floor(pos.y / occupation_chunk))

func place_building(building_type: BuildingType, world_position: Vector2, fraction: FractionSystem.FractionType) -> bool:
	if not can_place_building(building_type, world_position, fraction):
		return false
	
	var building_data = building_definitions.get_building_data(building_type)
	
	# Create building visual node
	var building_node = Node2D.new()
	building_node.global_position = world_position
	
	# Add sprite if available
	if not building_data.sprite:
		building_data.sprite = building_data.icon
	if building_data.sprite:
		var sprite = Sprite2D.new()
		sprite.texture = building_data.sprite
		Utils.normalize_sprite_uniform(sprite, building_data.scale * building_scale)
		sprite.modulate = building_data.color_tint
		building_node.add_child(sprite)
	
	parent_node.add_child(building_node)
	
	# Add to influence system
	var radiant_id = radiant_system.add_radiant(
		building_node,
		building_data.influence_strength,
		building_data.influence_radius
	)
	
	# Add to placed buildings
	var placed_building = PlacedBuilding.new(building_data, world_position, radiant_id, building_node)
	placed_buildings.append(placed_building)
	
	# Reduce inventory
	inventory[building_type] -= 1
	
	
	return true


func get_building_count(building_type: BuildingType) -> int:
	return inventory.get(building_type, 0)

func get_building_data(building_type: BuildingType) -> BuildingData:
	return building_definitions.get_building_data(building_type)

func get_selected_building_data() -> BuildingData:
	return building_definitions.get_building_data(selected_building_type)

func select_building(building_type: BuildingType):
	selected_building_type = building_type
