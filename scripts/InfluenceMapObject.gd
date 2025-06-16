extends Node2D

func _ready():
	# Create influence map
	var influence_map = InfluenceMap.new()
	add_child(influence_map)
	
	# Create contour renderer
	var contour_renderer = InfluenceMapRenderer.new()
	contour_renderer.influence_map = influence_map
	contour_renderer.contour_threshold = 1.0
	contour_renderer.update_frequency = 0.05 # 20 FPS updates
	contour_renderer.smoothing_iterations = 3
	
	add_child(contour_renderer)
