class_name GameState
extends BaseState


const inventory_menu_scene = preload("res://src/GUI/InventoryMenu/inventory_menu.tscn")

@export var reticle: Reticle

func get_action() -> Action:
	var action: Action = null
	
	for direction in Grid.DIRECTIONS:
		if Input.is_action_just_pressed(direction):
			var offset: Vector2i = Grid.DIRECTIONS[direction]
			action = BumpAction.new(player, offset.x, offset.y)
	
	if Input.is_action_just_pressed("wait"):
		action = WaitAction.new(player)
	
	if Input.is_action_just_pressed("view_history"):
		state_stack.push(state_stack.history_state)
		return null
	
	if Input.is_action_just_pressed("pickup"):
		action = PickupAction.new(player)
	
	#if Input.is_action_just_pressed("drop"):
	#	var selected_item: Entity = await get_item("Select an item to drop", player.inventory_component)
	#	action = DropItemAction.new(player, selected_item)
	
	if Input.is_action_just_pressed("look"):
		await get_grid_position(player, 0)
	
	if Input.is_action_just_pressed("descend"):
		action = TakeStairsAction.new(player)
		
	if Input.is_action_just_pressed("ui_cancel"):
		state_stack.push(state_stack.pause_state)
		return null
	
	if Input.is_action_just_pressed("inventory"):
		state_stack.push(state_stack.inventory_state)
		return null
		
	
	return action


func get_grid_position(player: Entity, radius: int) -> Vector2i:
	get_parent().transition_to(InputHandler.InputHandlers.DUMMY)
	var selected_position: Vector2i = await reticle.select_position(player, radius)
	await get_tree().physics_frame
	get_parent().call_deferred("transition_to", InputHandler.InputHandlers.MAIN_GAME)
	return selected_position
