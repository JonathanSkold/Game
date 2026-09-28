class_name BaseState
extends Node

var state_stack: StateStack
var player: Entity


func enter() -> void:
	pass


func exit() -> void:
	pass


func suspend() -> void:
	pass


func resume() -> void:
	pass


func handle_input(_event: InputEvent) -> Action:
	return null

func pressed(event: InputEvent, action: String) -> bool:
	return event.is_action_pressed(action, false, true)
