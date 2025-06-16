shader_type canvas_item;

uniform sampler2D map_texture;
uniform sampler2D color_map;
uniform float tile_size;

void fragment() {
	// Convert screen UV to map tile coordinate
	vec2 screen_pos = FRAGCOORD.xy;
	vec2 map_uv = floor(screen_pos / tile_size);
	vec2 map_size = vec2(textureSize(map_texture, 0));

	if (map_uv.x < 0.0 || map_uv.y < 0.0 || map_uv.x >= map_size.x || map_uv.y >= map_size.y) {
		COLOR = vec4(0.0);
		return;
	}

	vec2 uv = map_uv / map_size;
	vec4 data = texture(map_texture, uv);

	float faction_id = data.r * 255.0;
	float influence = data.g;

	vec2 color_uv = vec2(faction_id / float(textureSize(color_map, 0).x), 0.0);
	vec4 faction_color = texture(color_map, color_uv);

	COLOR = vec4(faction_color.rgb * influence, influence);
}
