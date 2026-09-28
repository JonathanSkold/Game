class_name InventoryShortcuts
extends RefCounted


static func backpack_item(player: Entity, keycode: int) -> Entity:
	var inventory: InventoryComponent = player.inventory_component

	if inventory == null:
		return null

	var index: int = -1

	if keycode >= KEY_1 and keycode <= KEY_9:
		index = keycode - KEY_1
	elif keycode == KEY_0:
		index = 9

	if index < 0 or index >= inventory.items.size():
		return null

	return inventory.items[index]


static func attached_item(player: Entity, keycode: int) -> Entity:
	var attachment: AttachmentComponent = player.attachment_component

	if attachment == null:
		return null

	if keycode < KEY_A or keycode > KEY_Z:
		return null

	var items: Array[Entity] = attachment.get_attached_items()
	var index: int = keycode - KEY_A

	if index >= items.size():
		return null

	return items[index]
