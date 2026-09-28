class_name InventoryPanel
extends PanelContainer

@export var item_label_settings: LabelSettings

@onready var equipped_list: VBoxContainer = %EquippedList
@onready var inventory_list: VBoxContainer = %InventoryList

var _inventory: InventoryComponent
var _equipment: EquipmentComponent


func setup(player: Entity) -> void:
	_disconnect_components()

	_inventory = player.inventory_component
	_equipment = player.equipment_component

	_inventory.inventory_changed.connect(refresh)
	_equipment.equipment_changed.connect(refresh)

	refresh()


func _disconnect_components() -> void:
	if is_instance_valid(_inventory):
		if _inventory.inventory_changed.is_connected(refresh):
			_inventory.inventory_changed.disconnect(refresh)

	if is_instance_valid(_equipment):
		if _equipment.equipment_changed.is_connected(refresh):
			_equipment.equipment_changed.disconnect(refresh)


func refresh() -> void:
	_clear_list(equipped_list)
	_clear_list(inventory_list)

	if not is_instance_valid(_inventory):
		return
	if not is_instance_valid(_equipment):
		return

	for index in range(_inventory.items.size()):
		var item: Entity = _inventory.items[index]
		var shortcut: String = String.chr("a".unicode_at(0) + index)
		var text: String = "(%s) %s" % [
			shortcut,
			item.get_entity_name()
		]

		if _equipment.is_item_equipped(item):
			_add_row(equipped_list, text)
		else:
			_add_row(inventory_list, text)

	if equipped_list.get_child_count() == 0:
		_add_row(equipped_list, "Nothing equipped")

	if inventory_list.get_child_count() == 0:
		_add_row(inventory_list, "No unequipped items")


func _clear_list(list: VBoxContainer) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()


func _add_row(list: VBoxContainer, text: String) -> void:
	var row := Label.new()
	row.text = text
	row.label_settings = item_label_settings
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(row)
