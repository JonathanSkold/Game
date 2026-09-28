class_name GameState
extends BaseState


const inventory_menu_scene = preload("res://src/GUI/InventoryMenu/inventory_menu.tscn")

@export var reticle: Reticle


func handle_input(event: InputEvent) -> Action:
	if event is InputEventKey:
		var is_letter: bool = \
			event.keycode >= KEY_A and event.keycode <= KEY_Z
		var is_number: bool = \
			event.keycode >= KEY_0 and event.keycode <= KEY_9

		if is_letter or is_number:
			if event.shift_pressed and event.ctrl_pressed:
				var first_item: Entity

				if is_letter:
					first_item = _get_attached_item(event.keycode)
				else:
					first_item = _get_backpack_item(event.keycode)

				if not is_instance_valid(first_item):
					return null

				if first_item.attachable_component == null:
					MessageLog.send_message(
						"That item cannot be attached.",
						GameColors.IMPOSSIBLE
					)
					return null

				state_stack.swap_state.setup(first_item, is_letter)
				state_stack.push(state_stack.swap_state)
				return null

			if event.shift_pressed:
				if is_number:
					return AttachAction.new(
						player,
						_get_backpack_item(event.keycode)
					)
				return null

			if event.ctrl_pressed:
				if is_letter:
					return DetachAction.new(
						player,
						_get_attached_item(event.keycode)
					)

				return DropItemAction.new(
					player,
					_get_backpack_item(event.keycode)
				)

			if event.alt_pressed:
				var item: Entity

				if is_letter:
					item = _get_attached_item(event.keycode)
				else:
					item = _get_backpack_item(event.keycode)

				if is_instance_valid(item):
					print(item.get_entity_name())

				return null
	
	for direction in Grid.DIRECTIONS:
		if pressed(event, direction):
			var offset: Vector2i = Grid.DIRECTIONS[direction]
			return BumpAction.new(player, offset.x, offset.y)

	if pressed(event, "wait"):
		return WaitAction.new(player)

	if pressed(event, "pickup"):
		return PickupAction.new(player)
	
	if pressed(event, "attach_from_ground"):
		return AttachFromGroundAction.new(player)

	if pressed(event, "descend"):
		return TakeStairsAction.new(player)

	if pressed(event, "view_history"):
		state_stack.push(state_stack.history_state)
	
	elif pressed(event, "ui_cancel"):
		state_stack.push(state_stack.pause_state)

	return null

func _get_backpack_item(keycode: int) -> Entity:
	return InventoryShortcuts.backpack_item(player, keycode)


func _get_attached_item(keycode: int) -> Entity:
	return InventoryShortcuts.attached_item(player, keycode)
