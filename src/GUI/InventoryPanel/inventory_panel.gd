class_name InventoryPanel
extends Control

@onready var attached_list: VBoxContainer = %AttachedList
@onready var inventory_list: VBoxContainer = %InventoryList

var _inventory: InventoryComponent
var _attachment: AttachmentComponent


func setup(player: Entity) -> void:
	_disconnect_components()

	_inventory = player.inventory_component
	_attachment = player.attachment_component

	_inventory.inventory_changed.connect(refresh)
	_attachment.attachments_changed.connect(refresh)

	refresh()


func _disconnect_components() -> void:
	if is_instance_valid(_inventory):
		if _inventory.inventory_changed.is_connected(refresh):
			_inventory.inventory_changed.disconnect(refresh)

	if is_instance_valid(_attachment):
		if _attachment.attachments_changed.is_connected(refresh):
			_attachment.attachments_changed.disconnect(refresh)


func refresh() -> void:
	_clear_list(attached_list)
	_clear_list(inventory_list)

	if not is_instance_valid(_inventory):
		return
	if not is_instance_valid(_attachment):
		return

	var attached_items: Array[Entity] = _attachment.get_attached_items()

	for index in range(attached_items.size()):
		var item: Entity = attached_items[index]
		var shortcut: String = String.chr("a".unicode_at(0) + index)

		_add_row(
			attached_list,
			"(%s) %s" % [shortcut, item.get_entity_name()]
		)

	for index in range(_inventory.items.size()):
		var item: Entity = _inventory.items[index]
		var shortcut: String = "-"

		if index < 10:
			shortcut = str((index + 1) % 10)

		_add_row(
			inventory_list,
			"(%s) %s" % [shortcut, item.get_entity_name()]
		)


func _clear_list(list: VBoxContainer) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()


func _add_row(list: VBoxContainer, text: String) -> void:
	var row := Label.new()
	row.text = text
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(row)
