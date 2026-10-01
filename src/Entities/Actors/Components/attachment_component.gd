class_name AttachmentComponent
extends Component

signal attachments_changed

var slots := {}

func get_save_data() -> Dictionary:
	var entries: Array = []
	var slot_keys: Array = slots.keys()
	slot_keys.sort()

	for slot in slot_keys:
		var item: Entity = slots[slot]

		entries.append({
			"slot": slot,
			"item": item.get_save_data(),
		})

	return {"attached_items": entries}


static func validate_save_data(data: Variant, depth: int = 0) -> String:
	if not data is Dictionary:
		return "Attachment data must be a dictionary."

	if not data.get("attached_items") is Array:
		return "attached_items must be an array."

	var entries: Array = data["attached_items"]
	var used_slots: Dictionary = {}
	var valid_slots: Array = AttachableComponent.AttachmentType.values()

	for index in range(entries.size()):
		var entry: Variant = entries[index]
		var context := "attached_items[%d]" % index

		if not entry is Dictionary:
			return "%s must be a dictionary." % context

		var saved_slot: Variant = entry.get("slot")

		if not SaveChecks.is_integer(saved_slot):
			return "%s.slot must be a whole number." % context

		var slot := int(saved_slot)

		if not valid_slots.has(slot):
			return "%s has an unknown attachment slot." % context

		if used_slots.has(slot):
			return "%s repeats an occupied attachment slot." % context

		used_slots[slot] = true

		var item_data: Variant = entry.get("item")
		var error := Entity.validate_save_data(item_data, depth + 1)

		if not error.is_empty():
			return "%s.item: %s" % [context, error]

		var definition: EntityDefinition = load(
			Entity.entity_types[item_data["key"]]
		)

		if definition.type != Entity.EntityType.ITEM:
			return "%s.item is not an item." % context

		var attachment_definition := (
			definition.item_definition as AttachableComponentDefinition
		)

		if attachment_definition == null:
			return "%s.item cannot be attached." % context

		if int(attachment_definition.attachment_type) != slot:
			return "%s.item does not fit its saved slot." % context

	return ""

# Requires validated data and a fresh, empty attachment component.
func restore_save_data(data: Dictionary) -> void:
	assert(slots.is_empty(), "Restore requires empty attachment slots.")

	for entry in data["attached_items"]:
		var item := Entity.create(null, Vector2i.ZERO, "")
		item.restore_save_data(entry["item"])
		store_item(item)
			

func is_item_attached(item: Entity) -> bool:
	return item in slots.values()

# Caller validates availability and compatibility first.
func store_item(item: Entity) -> void:
	assert(item.get_parent() == null)
	assert(item.attachable_component != null)

	var slot := item.attachable_component.attachment_type
	assert(not slots.has(slot))

	slots[slot] = item
	item.move_into_storage(self)


func release_item(item: Entity) -> void:
	assert(item.attachable_component != null)

	var slot := item.attachable_component.attachment_type
	assert(slots.get(slot) == item)
	assert(item.get_parent() == self)

	slots.erase(slot)
	remove_child(item)

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
	
	inventory.release_item(item)
	store_item(item)

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

	map_data.entities.erase(item)
	item.get_parent().remove_child(item)
	store_item(item)

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
	
	release_item(item)
	inventory.store_item(item)
	
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
	inventory.release_item(backpack_item)
	release_item(attached_item)

	inventory.store_item(attached_item, backpack_index)
	store_item(backpack_item)

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
