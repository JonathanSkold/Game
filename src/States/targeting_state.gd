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

func get_action() -> Action:
	var offset := Vector2i.ZERO
	
	for direction in Grid.DIRECTIONS:
		if Input.is_action_just_pressed(direction):
			offset += Grid.DIRECTIONS[direction]
	
	if offset != Vector2i.ZERO:
		reticle.move(offset)
	
	if Input.is_action_just_pressed("ui_accept"):
		targeting_finished.emit(reticle.grid_position)
		state_stack.pop()
		return null
	
	if Input.is_action_just_pressed("ui_back"):
		targeting_finished.emit(Vector2i(-1, -1))
		state_stack.pop()
		return null
	
	return null
