class_name TargetingState
extends BaseState

@export var reticle: Reticle

var item: Entity
var radius: int
var map_data: MapData

signal targeting_finished(position: Vector2i)


func setup(selected_item: Entity, target_radius: int) -> void:
	item = selected_item
	radius = target_radius

func enter() -> void:
	map_data = player.map_data
	reticle.activate(player.grid_position, radius)

func exit() -> void:
	reticle.deactivate()


func handle_input(event: InputEvent) -> Action:
	if pressed(event, "ui_accept"):
		_finish(reticle.grid_position)
		return null

	if pressed(event, "ui_back"):
		_finish(Vector2i(-1, -1))
		return null

	for direction in Grid.DIRECTIONS:
		if pressed(event, direction):
			reticle.move(Grid.DIRECTIONS[direction])
			return null

	return null


func _finish(position: Vector2i) -> void:
	state_stack.pop()
	targeting_finished.emit(position)
