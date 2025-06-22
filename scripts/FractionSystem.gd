extends RefCounted
class_name FractionSystem

enum FractionType {
    NONE = 0,
    RED = 1,
    BLUE = 2,
    GREEN = 3,
}

var fraction_colors: Dictionary = {
    FractionType.RED: Color.RED, # Color(0.8, 0.1, 0.1), # Red
    FractionType.BLUE: Color.BLUE, # Color(0.1, 0.1, 0.8), # Blue
    FractionType.GREEN: Color.GREEN, # Color(0.1, 0.8, 0.1), # Green
}

var fraction_names: Dictionary = {
    FractionType.RED: "Red Fraction",
    FractionType.BLUE: "Blue Fraction",
    FractionType.GREEN: "Green Fraction",
}

var relations: Dictionary = {}

func _init():
    setup_default_relations()

func setup_default_relations():
    # Define relationships between fractions
    # 1.0 = allied, 0.0 = neutral, -1.0 = hostile
    # Add more relations as needed...
    relations[FractionType.RED] = {
        FractionType.BLUE: - 1.0,
        FractionType.GREEN: 0.0,
    }
    relations[FractionType.BLUE] = {
        FractionType.RED: - 1.0,
        FractionType.GREEN: 1.0,
    }
func get_relation(fraction_a: FractionType, fraction_b: FractionType) -> float:
    if relations.has(fraction_a) and relations[fraction_a].has(fraction_b):
        return relations[fraction_a][fraction_b]
    return 0.0

func are_hostile(fraction_a: FractionType, fraction_b: FractionType) -> bool:
    return get_relation(fraction_a, fraction_b) < 0.0

func are_allied(fraction_a: FractionType, fraction_b: FractionType) -> bool:
    return get_relation(fraction_a, fraction_b) > 0.5

func get_fraction_color(fraction: FractionType) -> Color:
    return fraction_colors.get(fraction, Color.WHITE)

func get_fraction_name(fraction: FractionType) -> String:
    return fraction_names.get(fraction, "Unknown")