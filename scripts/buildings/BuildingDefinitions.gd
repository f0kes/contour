extends Resource
class_name BuildingDefinitions

@export var buildings: Array[BuildingData] = []

func get_building_data(building_type: BuildingSystem.BuildingType) -> BuildingData:
	for building in buildings:
		if building.type == building_type:
			return building
	return null
