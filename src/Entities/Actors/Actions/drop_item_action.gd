class_name DropItemAction
extends Action

var _item: Entity

func _init(entity: Entity, item: Entity) -> void:
	super._init(entity)
	_item = item

func perform() -> bool:
	if not is_instance_valid(_item):
		return false

	var inventory: InventoryComponent = entity.inventory_component

	if inventory == null:
		return false

	if not inventory.items.has(_item):
		return false

	var attachment: AttachmentComponent = entity.attachment_component

	if attachment != null and attachment.is_item_attached(_item):
		return false

	inventory.drop(_item)
	return true
