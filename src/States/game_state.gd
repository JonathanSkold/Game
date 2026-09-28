class_name GameState
extends BaseState


const inventory_menu_scene = preload("res://src/GUI/InventoryMenu/inventory_menu.tscn")

@export var reticle: Reticle


func handle_input(event: InputEvent) -> Action:
	if event is InputEventKey:
		if event.keycode >= KEY_A and event.keycode <= KEY_Z:
			if event.ctrl_pressed:
				return EquipAction.new(player, _get_inventory_item(event.keycode))

			if event.alt_pressed:
				return DropItemAction.new(player, _get_inventory_item(event.keycode)
				)

			if event.shift_pressed:
				var item: Entity = _get_inventory_item(event.keycode)

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

	if pressed(event, "descend"):
		return TakeStairsAction.new(player)

	if pressed(event, "view_history"):
		state_stack.push(state_stack.history_state)
	
	elif pressed(event, "ui_cancel"):
		state_stack.push(state_stack.pause_state)
	
	elif pressed(event, "inventory"):
		state_stack.push(state_stack.inventory_state)

	return null

func _get_inventory_item(keycode: int) -> Entity:
	var inventory: InventoryComponent = player.inventory_component

	if inventory == null:
		return null

	var index: int = keycode - KEY_A

	if index < 0 or index >= inventory.items.size():
		return null

	return inventory.items[index]
