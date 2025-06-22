extends RefCounted
class_name ChunkManager

var chunk_size: int = 16
var chunk_matrix_cache: Dictionary = {}
var chunk_raw_cache: Dictionary = {} # Store raw values for lerping
var dirty_chunks: Array = []
var noise: FastNoiseLite
var noise_offset_vector: Vector2
var influence_system: InfluenceSystem

var max_concurrent_chunks: int = 4 # Maximum chunks loading at once
var chunk_queue: Array = [] # Queue of chunks waiting to be loaded


func _init(noise_instance: FastNoiseLite, offset: Vector2, inf_system: InfluenceSystem):
	noise = noise_instance
	noise_offset_vector = offset
	influence_system = inf_system

func world_to_chunk(world_pos: Vector2i) -> Vector2i:
	return Vector2i(world_pos.x / chunk_size, world_pos.y / chunk_size)

func generate_chunk(chunk_coord: Vector2i, mip_level: int):
	var chunk_data = []
	var chunk_raw_data = [] # Store raw values
	var chunk_key = str(chunk_coord) + "_" + str(mip_level)
	
	var start_x = chunk_coord.x * chunk_size
	var start_y = chunk_coord.y * chunk_size
	var chunk_size_mipped = chunk_size / mip_level
	
	for x in range(chunk_size_mipped):
		chunk_data.append([])
		chunk_raw_data.append([])
		for y in range(chunk_size_mipped):
			var world_x = (start_x + x * mip_level)
			var world_y = (start_y + y * mip_level)
			
			var noise_value = noise.get_noise_2d(
				world_x + noise_offset_vector.x,
				world_y + noise_offset_vector.y
			)
			
			var influence_value = influence_system.sample_influence_mipped(world_x, world_y, mip_level)
			var combined_value = noise_value + influence_value * 0.1
			
			chunk_data[x].append(1 if combined_value > 0 else 0)
			chunk_raw_data[x].append(combined_value) # Store raw value
	
	chunk_matrix_cache[chunk_key] = chunk_data
	chunk_raw_cache[chunk_key] = chunk_raw_data


func get_value_at(x: int, y: int, mip_level: int) -> int:
	var chunk_coord = world_to_chunk(Vector2i(x, y))
	var chunk_key = str(chunk_coord) + "_" + str(mip_level)
	
	if chunk_key in chunk_matrix_cache:
		var chunk_data = chunk_matrix_cache[chunk_key]
		var local_x = (x - chunk_coord.x * chunk_size) / mip_level
		var local_y = (y - chunk_coord.y * chunk_size) / mip_level
		
		if local_x < chunk_data.size() and local_y < chunk_data[local_x].size():
			return chunk_data[local_x][local_y]
	
	return 0

# New function to get raw values for lerping
func get_raw_value_at(x: int, y: int, mip_level: int) -> float:
	var chunk_coord = world_to_chunk(Vector2i(x, y))
	var chunk_key = str(chunk_coord) + "_" + str(mip_level)
	
	if chunk_key in chunk_raw_cache:
		var chunk_data = chunk_raw_cache[chunk_key]
		var local_x = (x - chunk_coord.x * chunk_size) / mip_level
		var local_y = (y - chunk_coord.y * chunk_size) / mip_level
		
		if local_x < chunk_data.size() and local_y < chunk_data[local_x].size():
			return chunk_data[local_x][local_y]
	
	# Fallback: calculate on the fly if not cached
	var noise_value = noise.get_noise_2d(
		x + noise_offset_vector.x,
		y + noise_offset_vector.y
	)
	var influence_value = influence_system.sample_influence_mipped(x, y, mip_level)
	return noise_value + influence_value * 0.1
