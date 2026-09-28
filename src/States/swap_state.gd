class_name SwapState
extends BaseState

var _first_item: Entity
var _first_is_attached: bool


func setup(item: Entity, from_attached: bool) -> void:
	_first_item = item
	_first_is_attached = from_attached


func enter() -> void:
	var destination: String = "an attached item (letter)"

	if _first_is_attached:
		destination = "a backpack item (number)"

	MessageLog.send_message(
		"Swap %s: choose %s. Escape cancels." % [
			_first_item.get_entity_name(),
			destination
		],
		Color.WHITE
	)


func exit() -> void:
	_first_item = null
	_first_is_attached = false


func handle_input(event: InputEvent) -> Action:
	if not event is InputEventKey:
		return null

	if not event.pressed or event.echo:
		return null

	if event.is_action_pressed("ui_back"):
		state_stack.pop()
		return null

	if not is_instance_valid(_first_item):
		state_stack.pop()
		return null

	var second_item: Entity

	if _first_is_attached:
		second_item = InventoryShortcuts.backpack_item(
			player,
			event.keycode
		)
	else:
		second_item = InventoryShortcuts.attached_item(
			player,
			event.keycode
		)

	# Wrong panel or empty entry: keep waiting.
	if not is_instance_valid(second_item):
		return null

	var action: SwapAction

	if _first_is_attached:
		action = SwapAction.new(
			player,
			_first_item,
			second_item
		)
	else:
		action = SwapAction.new(
			player,
			second_item,
			_first_item
		)

	state_stack.pop()
	return action
