class_name InventoryState
extends BaseState

signal action_requested(action: Action)

@export var inventory_menu_scene: PackedScene

var inventory_menu: InventoryMenu
var targeting_item: Entity


func enter() -> void:
	inventory_menu = inventory_menu_scene.instantiate()
	add_child(inventory_menu)

	inventory_menu.use_requested.connect(_on_use_requested)
	inventory_menu.drop_requested.connect(_on_drop_requested)
	inventory_menu.inspect_requested.connect(_on_inspect_requested)

	inventory_menu.build("Inventory", player.inventory_component)


func exit() -> void:
	if inventory_menu != null:
		inventory_menu.set_interaction_enabled(false)
		inventory_menu.queue_free()
		inventory_menu = null


func suspend() -> void:
	if inventory_menu != null:
		inventory_menu.set_interaction_enabled(false)


func resume() -> void:
	if inventory_menu != null:
		inventory_menu.set_interaction_enabled(true)


func handle_input(event: InputEvent) -> Action:
	if pressed(event, "inventory") or pressed(event, "ui_back"):
		state_stack.pop()

	return null


func _finish_with_action(action: Action) -> void:
	if state_stack.current() != self:
		return

	state_stack.pop()
	action_requested.emit(action)


func _on_inspect_requested(item: Entity) -> void:
	print(item.get_entity_name())


func _on_drop_requested(item: Entity) -> void:
	_finish_with_action(DropItemAction.new(player, item))


func _on_use_requested(item: Entity) -> void:
	if state_stack.current() != self:
		return

	var target_radius: int = -1

	if item.consumable_component != null:
		target_radius = item.consumable_component.get_targeting_radius()

	if target_radius == -1:
		_finish_with_action(ItemAction.new(player, item))
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
	var item: Entity = targeting_item
	targeting_item = null

	if position == Vector2i(-1, -1):
		return

	_finish_with_action(ItemAction.new(player, item, position))
