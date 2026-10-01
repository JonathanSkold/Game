class_name AIBehavior
extends Node

var controller: AIController
var entity: Entity


func get_save_type() -> String:
	assert(false, "Behavior must provide a save type.")
	return ""


func get_save_data() -> Dictionary:
	return {}


static func validate_save_data(data: Variant) -> String:
	if not data is Dictionary:
		return "Behavior data must be a dictionary."

	return ""


func restore_save_data(_data: Dictionary) -> void:
	pass


func enter() -> void:
	pass


func exit() -> void:
	pass


func suspend() -> void:
	pass


func resume() -> void:
	pass


func perform() -> void:
	pass


func get_map_data() -> MapData:
	return entity.map_data


func get_point_path_to(destination: Vector2i) -> PackedVector2Array:
	return get_map_data().pathfinder.get_point_path(
		entity.grid_position,
		destination
	)
