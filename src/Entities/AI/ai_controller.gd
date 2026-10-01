class_name AIController
extends Node

var entity: Entity
var _stack: Array[AIBehavior] = []

const BEHAVIOR_TYPES := {
	"hostile": {
		"script": "res://src/Entities/Actors/Components/hostile_enemy_ai_component.gd",
		"is_base": true,
	},
	"confused": {
		"script": "res://src/Entities/Actors/Components/confused_enemy_ai_component.gd",
		"is_base": false,
	},
}

func get_save_data() -> Dictionary:
	var entries: Array = []

	for behavior in _stack:
		entries.append({
			"type": behavior.get_save_type(),
			"data": behavior.get_save_data(),
		})

	return {"stack": entries}


static func validate_save_data(data: Variant) -> String:
	if not data is Dictionary:
		return "AI controller data must be a dictionary."

	if not data.get("stack") is Array:
		return "AI stack must be an array."

	var entries: Array = data["stack"]

	for index in range(entries.size()):
		var entry: Variant = entries[index]
		var context := "AI stack[%d]" % index

		if not entry is Dictionary:
			return "%s must be a dictionary." % context

		var type_id: Variant = entry.get("type")

		if not type_id is String:
			return "%s.type must be a string." % context

		if not BEHAVIOR_TYPES.has(type_id):
			return "%s has an unknown behavior: %s." % [
				context,
				type_id,
			]

		var registration: Dictionary = BEHAVIOR_TYPES[type_id]
		var is_base: bool = registration["is_base"]

		if index == 0 and not is_base:
			return "AI stack must start with a base behavior."

		if index > 0 and is_base:
			return "%s cannot place a base behavior above another." % context

		var behavior_script: Script = load(registration["script"])
		var error: String = behavior_script.validate_save_data(
			entry.get("data")
		)

		if not error.is_empty():
			return "%s: %s" % [context, error]

	return ""

# Requires validated data and an Entity still outside the SceneTree.
func restore_save_data(data: Dictionary) -> void:
	assert(not is_inside_tree())
	assert(_stack.is_empty(), "Restore requires an empty AI stack.")

	for entry in data["stack"]:
		var registration: Dictionary = BEHAVIOR_TYPES[entry["type"]]
		var behavior_script: Script = load(registration["script"])
		var behavior: AIBehavior = behavior_script.new()

		behavior.controller = self
		behavior.entity = entity
		behavior.restore_save_data(entry["data"])

		_stack.append(behavior)
		add_child(behavior)

func _init(actor: Entity) -> void:
	entity = actor


func current() -> AIBehavior:
	if _stack.is_empty():
		return null

	return _stack.back()


func push(behavior: AIBehavior) -> void:
	assert(behavior != null)
	assert(behavior.get_parent() == null)
	assert(behavior.controller == null)

	var previous := current()

	if previous != null:
		previous.suspend()

	behavior.controller = self
	behavior.entity = entity

	_stack.append(behavior)
	add_child(behavior)

	behavior.enter()


func pop(requester: AIBehavior) -> void:
	# Only the active behavior may finish itself.
	if current() != requester:
		return

	# The bottom behavior remains the actor's default.
	if _stack.size() <= 1:
		return

	var removed: AIBehavior = _stack.pop_back()
	removed.exit()
	remove_child(removed)
	removed.queue_free()

	current().resume()


func clear() -> void:
	# Remove everything without briefly resuming lower behaviors.
	while not _stack.is_empty():
		var removed: AIBehavior = _stack.pop_back()
		removed.exit()
		remove_child(removed)
		removed.queue_free()


func perform() -> void:
	var behavior := current()

	if behavior != null:
		behavior.perform()
