class_name InventoryMenu
extends CanvasLayer

signal use_requested(item: Entity)
signal drop_requested(item: Entity)
signal inspect_requested(item: Entity)

const inventory_menu_item_scene := preload("res://src/GUI/InventoryMenu/inventory_menu_item.tscn")

@onready var inventory_list: VBoxContainer = $"%InventoryList"
@onready var title_label: Label = $"%TitleLabel"

func _ready() -> void:
	hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	
	if not event.pressed or event.echo:
		return
	
	var index: int = event.keycode - KEY_A
	
	if index < 0 or index >= inventory_list.get_child_count():
		return
	
	var item: Entity = inventory_list.get_child(index).get_meta("item")
	
	if event.ctrl_pressed:
		use_requested.emit(item)
	elif event.alt_pressed:
		drop_requested.emit(item)
	elif event.shift_pressed:
		inspect_requested.emit(item)

func _register_item(index: int, item: Entity, is_equipped: bool) -> void:
	var item_button: Button = inventory_menu_item_scene.instantiate()
	
	var char: String = String.chr("a".unicode_at(0) + index)
	item_button.text = "( %s ) %s" % [char, item.get_entity_name()]
	
	if is_equipped:
		item_button.text += " (E)"
	
	item_button.set_meta("item", item)
	
	inventory_list.add_child(item_button)

#func button_pressed(item: Entity = null) -> void:
#	item_selected.emit(item)
#	queue_free()


func build(title_text: String, inventory: InventoryComponent) -> void:
	title_label.text = title_text
	if inventory.items.is_empty():
		show()
		return
	var equipment: EquipmentComponent = inventory.entity.equipment_component
	for i in inventory.items.size():
		var item: Entity = inventory.items[i]
		var is_equipped: bool = equipment.is_item_equipped(item)
		_register_item(i, item, is_equipped)
	inventory_list.get_child(0).grab_focus()
	show()
