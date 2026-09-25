class_name StateStack
extends Node

var player: Entity
var states: Array[BaseState] = []

@onready var game_state: GameState = $GameState
@onready var inventory_state: InventoryState = $InventoryState
@onready var targeting_state: TargetingState = $TargetingState
@onready var history_state: HistoryState = $HistoryState

@onready var pause_state: PauseState = $PauseState

@onready var start_state: BaseState = game_state


func start() -> void:
	push(start_state)

func push(state: BaseState) -> void:
	assert(state != null, "Cannot push a null BaseState")
	
	if not states.is_empty():
		states.back().suspend()

	states.push_back(state)
	state.state_stack = self
	state.player = player
	state.enter()


func pop() -> void:
	if states.size() <= 1:
		return

	var old_state: BaseState = states.pop_back()
	old_state.exit()

	states.back().resume()


func replace(state: BaseState) -> void:
	if not states.is_empty():
		var old_state: BaseState = states.pop_back()
		old_state.exit()

	states.push_back(state)
	state.state_stack = self
	state.enter()


func current() -> BaseState:
	if states.is_empty():
		return null

	return states.back()

func get_action() -> Action:
	if states.is_empty():
		return null
	
	return await states.back().get_action()
