class_name InventoryState
extends BaseState

@export var inventory_menu_scene: PackedScene
var inventory_menu: InventoryMenu
var pending_action: Action
var targeting_item: Entity

func enter() -> void:
	inventory_menu = inventory_menu_scene.instantiate()
	add_child(inventory_menu)
	
	inventory_menu.use_requested.connect(_on_use_requested)
	inventory_menu.drop_requested.connect(_on_drop_requested)
	inventory_menu.inspect_requested.connect(_on_inspect_requested)
	
	inventory_menu.build(
		"Inventory",
		player.inventory_component
	)

func exit() -> void:
	if inventory_menu != null:
		inventory_menu.queue_free()
		inventory_menu = null


func get_action() -> Action:
	if pending_action != null:
		var action: Action = pending_action
		pending_action = null
		state_stack.pop()
		return action
		
	if Input.is_action_just_pressed("inventory") or Input.is_action_just_pressed("ui_back"):
		state_stack.pop()
	
	return null

func _on_inspect_requested(item: Entity) -> void:
	print(item.get_entity_name())

func _on_drop_requested(item: Entity) -> void:
	pending_action = DropItemAction.new(player, item)

func _on_use_requested(item: Entity) -> void:
	var target_radius: int = -1
	
	if item.consumable_component != null:
		target_radius = item.consumable_component.get_targeting_radius()
	
	if target_radius == -1:
		pending_action = ItemAction.new(player, item)
		return
	
	targeting_item = item
	var targeting_state: TargetingState = state_stack.targeting_state
	targeting_state.setup(item, target_radius)
	
	targeting_state.targeting_finished.connect(
	_on_targeting_finished,
	CONNECT_ONE_SHOT
	)
	
	state_stack.push(targeting_state)

func _on_targeting_finished(position: Vector2i) -> void:
	if position != Vector2i(-1, -1):
		pending_action = ItemAction.new(player, targeting_item, position)
	
	targeting_item = null
