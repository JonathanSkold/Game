class_name AttachmentComponent
extends Component

signal attachments_changed

var slots := {}

func get_save_data() -> Dictionary:
	var entries: Array = []

	for slot in slots:
		var item: Entity = slots[slot]

		entries.append({
			"slot": slot,
			"item": item.get_save_data(),
		})

	return {"attached_items": entries}

func restore(save_data: Dictionary) -> void:
	var inventory: InventoryComponent = entity.inventory_component

	if save_data.has("attached_items"):
		for entry in save_data["attached_items"]:
			var item := Entity.create(null, Vector2i(-1, -1), "")
			item.restore(entry["item"])
			slots[int(entry["slot"])] = item

	inventory.inventory_changed.emit()
	attachments_changed.emit()
			

func is_item_attached(item: Entity) -> bool:
	return item in slots.values()

func attach(item: Entity, add_message: bool = true) -> bool:
	if not is_instance_valid(item):
		return false

	if item.attachable_component == null:
		return false
	
	var inventory: InventoryComponent = entity.inventory_component

	if inventory == null or not inventory.items.has(item):
		return false

	var slot: AttachableComponent.AttachmentType = item.attachable_component.attachment_type

	if slots.get(slot) != null:
		if add_message:
			MessageLog.send_message(
				"That attachment slot is occupied.",
				GameColors.IMPOSSIBLE
			)
		return false
	
	inventory.items.erase(item)
	
	slots[slot] = item

	if add_message:
		MessageLog.send_message(
			"You attach the %s." % item.get_entity_name(),
			Color.WHITE
		)
	
	inventory.inventory_changed.emit()
	attachments_changed.emit()
	return true

func attach_from_ground(item: Entity) -> bool:
	if not is_instance_valid(item):
		return false

	var map_data: MapData = entity.map_data

	if map_data == null or not map_data.entities.has(item):
		return false

	if item.grid_position != entity.grid_position:
		return false

	if item.attachable_component == null:
		MessageLog.send_message(
			"That item cannot be attached.",
			GameColors.IMPOSSIBLE
		)
		return false

	var slot: AttachableComponent.AttachmentType = \
		item.attachable_component.attachment_type

	if slots.get(slot) != null:
		MessageLog.send_message(
			"That attachment slot is occupied.",
			GameColors.IMPOSSIBLE
		)
		return false

	# Validation is complete. Transfer ownership.
	map_data.entities.erase(item)
	slots[slot] = item

	var parent: Node = item.get_parent()
	if parent != null:
		parent.remove_child(item)

	MessageLog.send_message(
		"You attach the %s from the ground." % item.get_entity_name(),
		Color.WHITE
	)

	attachments_changed.emit()
	return true

func detach(item: Entity, add_message: bool = true) -> bool:
	if not is_instance_valid(item):
		return false

	if item.attachable_component == null:
		return false

	var slot: AttachableComponent.AttachmentType = item.attachable_component.attachment_type

	if slots.get(slot) != item:
		return false
	
	var inventory: InventoryComponent = entity.inventory_component

	if inventory == null:
		return false

	if inventory.is_full():
		if add_message:
			MessageLog.send_message(
				"Your inventory is full.",
				GameColors.IMPOSSIBLE
			)
		return false
	
	slots.erase(slot)
	
	inventory.items.append(item)
	
	if add_message:
		MessageLog.send_message(
			"You detach the %s." % item.get_entity_name(),
			Color.WHITE
		)
	
	inventory.inventory_changed.emit()
	attachments_changed.emit()
	return true

func swap_with_inventory(
	attached_item: Entity,
	backpack_item: Entity
) -> bool:
	if not is_instance_valid(attached_item):
		return false

	if not is_instance_valid(backpack_item):
		return false

	if attached_item == backpack_item:
		return false

	var inventory: InventoryComponent = entity.inventory_component

	if inventory == null:
		return false

	if attached_item.attachable_component == null:
		return false

	if backpack_item.attachable_component == null:
		MessageLog.send_message(
			"That item cannot be attached.",
			GameColors.IMPOSSIBLE
		)
		return false

	var slot: AttachableComponent.AttachmentType = \
		attached_item.attachable_component.attachment_type

	if slots.get(slot) != attached_item:
		return false

	if inventory.items.has(attached_item):
		return false

	var backpack_index: int = inventory.items.find(backpack_item)

	if backpack_index == -1 or is_item_attached(backpack_item):
		return false

	if backpack_item.attachable_component.attachment_type != slot:
		MessageLog.send_message(
			"Those items use different attachment slots.",
			GameColors.IMPOSSIBLE
		)
		return false

	# All validation is complete. Exchange both references.
	inventory.items[backpack_index] = attached_item
	slots[slot] = backpack_item

	MessageLog.send_message(
		"You detach the %s and attach the %s." % [
			attached_item.get_entity_name(),
			backpack_item.get_entity_name()
		],
		Color.WHITE
	)

	inventory.inventory_changed.emit()
	attachments_changed.emit()
	return true

func get_attached_items() -> Array[Entity]:
	var result: Array[Entity] = []
	var slot_keys: Array = slots.keys()
	slot_keys.sort()

	for slot in slot_keys:
		var item: Entity = slots[slot]
		result.append(item)

	return result

func get_defense_bonus() -> int:
	var bonus = 0
	
	for item in slots.values():
		if item.attachable_component:
			bonus += item.attachable_component.defense_bonus
	
	return bonus

func get_power_bonus() -> int:
	var bonus = 0
	
	for item in slots.values():
		if item.attachable_component:
			bonus += item.attachable_component.power_bonus
	
	return bonus
