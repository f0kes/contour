extends Object
class_name Utils


static func normalize_sprite(sprite: Sprite2D, target_size: Vector2):
	var tex_size = sprite.texture.get_size()
	sprite.scale = target_size / tex_size

static  func normalize_sprite_uniform(sprite: Sprite2D, target_size: float):
	normalize_sprite(sprite, Vector2(target_size, target_size))
