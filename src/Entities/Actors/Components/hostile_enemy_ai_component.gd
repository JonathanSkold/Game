class_name HostileEnemyAIComponent
extends AIBehavior

var path: Array = []

func get_save_type() -> String:
	return "hostile"


func get_save_data() -> Dictionary:
	var saved_path: Array = []

	for point in path:
		var cell := Vector2i(point)
		saved_path.append({"x": cell.x, "y": cell.y})

	return {"path": saved_path}


static func validate_save_data(data: Variant) -> String:
	if not data is Dictionary:
		return "Hostile behavior data must be a dictionary."

	if not data.get("path") is Array:
		return "Hostile path must be an array."

	var saved_path: Array = data["path"]

	for index in range(saved_path.size()):
		var point: Variant = saved_path[index]

		if not point is Dictionary:
			return "path[%d] must be a dictionary." % index

		if not SaveChecks.is_integer(point.get("x")):
			return "path[%d].x must be a whole number." % index

		if not SaveChecks.is_integer(point.get("y")):
			return "path[%d].y must be a whole number." % index

	return ""


func restore_save_data(data: Dictionary) -> void:
	path.clear()

	for point in data["path"]:
		path.append(Vector2i(int(point["x"]), int(point["y"])))

func resume() -> void:
	# A temporary behavior may have moved the actor elsewhere.
	path.clear()

func perform() -> void:
	var target: Entity = get_map_data().player
	var target_grid_position: Vector2i = target.grid_position
	var offset: Vector2i = target_grid_position - entity.grid_position
	var distance: int = max(abs(offset.x), abs(offset.y))
	
	if get_map_data().get_tile(entity.grid_position).is_in_view:
		if distance <= 1:
			return MeleeAction.new(entity, offset.x, offset.y).perform()
		
		path = get_point_path_to(target_grid_position)
		path.pop_front()
	
	if not path.is_empty():
		var destination := Vector2i(path[0])
		if get_map_data().get_blocking_entity_at_location(destination):
			return WaitAction.new(entity).perform()
		path.pop_front()
		var move_offset: Vector2i = destination - entity.grid_position
		return MovementAction.new(entity, move_offset.x, move_offset.y).perform()
	
	return WaitAction.new(entity).perform()
