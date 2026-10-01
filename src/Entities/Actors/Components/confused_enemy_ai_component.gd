class_name ConfusedEnemyAIComponent
extends AIBehavior

var turns_remaining: int


func get_save_type() -> String:
	return "confused"


func get_save_data() -> Dictionary:
	return {"turns_remaining": turns_remaining}


static func validate_save_data(data: Variant) -> String:
	if not data is Dictionary:
		return "Confused behavior data must be a dictionary."

	if not SaveChecks.is_integer(data.get("turns_remaining")):
		return "turns_remaining must be a whole number."

	if data["turns_remaining"] < 0:
		return "turns_remaining cannot be negative."

	return ""


func restore_save_data(data: Dictionary) -> void:
	turns_remaining = int(data["turns_remaining"])


func _init(duration: int = 0) -> void:
	turns_remaining = duration


func perform() -> void:
	if turns_remaining <= 0:
		controller.pop(self)

		# Another confusion behavior might still be underneath.
		if not controller.current() is ConfusedEnemyAIComponent:
			MessageLog.send_message(
				"The %s is no longer confused." % entity.get_entity_name(),
				Color.WHITE
			)

		return

	var direction: Vector2i = Grid.DIRECTIONS.values().pick_random()
	turns_remaining -= 1

	BumpAction.new(entity, direction.x, direction.y).perform()
