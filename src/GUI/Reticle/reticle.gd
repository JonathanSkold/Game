class_name Reticle
extends Node2D


var grid_position: Vector2i:
	set(value):
		grid_position = value
		position = Grid.grid_to_world(grid_position)

@onready var border: Line2D = $Line2D

func _ready() -> void:
	hide()

func activate(start_position: Vector2i, radius: int) -> void:
	grid_position = start_position
	_setup_border(radius)
	show()

func deactivate() -> void:
	hide()

func move(offset: Vector2i) -> void:
	grid_position += offset

func _setup_border(radius: int) -> void:
	if radius <= 0:
		border.hide()
	else:
		border.points = [
			Vector2i(-radius, -radius) * Grid.tile_size,
			Vector2i(-radius, radius + 1) * Grid.tile_size,
			Vector2i(radius + 1, radius + 1) * Grid.tile_size,
			Vector2i(radius + 1, -radius) * Grid.tile_size,
			Vector2i(-radius, -radius) * Grid.tile_size
		]
		border.show()
