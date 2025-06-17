extends Node2D
class_name RandomMove
var speed: float = 100.0
var direction: Vector2 = Vector2.ZERO

func _ready():
    direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func _process(delta: float):
    position += direction * speed * delta
    if randi() % 120 == 0:
        direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()