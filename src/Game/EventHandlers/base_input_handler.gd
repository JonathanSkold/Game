class_name BaseInputHandler
extends Node


func enter() -> void:
	await get_tree().process_frame
	#pass


func exit() -> void:
	pass


func get_action(player: Entity) -> Action:
	return null
