extends Node2D
@onready var ui_panel: Panel = $CanvasLayer/MarchingSquaresUI
@onready var offset_move_timer: Timer = $OffsetMoveTimer

func _ready():
	# Setup timer
	print("Starting")
	offset_move_timer.wait_time = 0.1
	offset_move_timer.timeout.connect(_on_offset_move_timer_timeout)
	
	print("Controls:")
	print("Left Click: Add positive influence")
	print("Right Click: Add negative influence")
	print("Mouse Wheel: Zoom in/out")
	print("Space + Mouse: Paint influence while dragging")
	print("Shift + Space + Mouse: Paint negative influence")
	print("R: Reset influence")
	print("+/-: Zoom in/out")
	print("0: Reset zoom")

func _on_offset_move_timer_timeout():
	# This will be handled by the UI panel
	pass
