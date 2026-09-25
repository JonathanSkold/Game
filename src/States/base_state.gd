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


func get_action() -> Action:
	return null
