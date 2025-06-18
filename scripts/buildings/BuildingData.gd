extends Resource
class_name BuildingData


@export var type: BuildingSystem.BuildingType
@export var building_name: String = "Building"
@export var description: String = "A building"
@export var icon: Texture2D
@export var cost: int = 50
@export var influence_radius: float = 8.0
@export var influence_strength: float = 15.0
@export var build_time: float = 1.0

# Optional visual properties
@export var sprite: Texture2D
@export var scale: float = 1.0
@export var color_tint: Color = Color.WHITE