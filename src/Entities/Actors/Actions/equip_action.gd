class_name EquipAction
extends Action

var _item: Entity

func _init(entity: Entity, item: Entity) -> void:
	super._init(entity)
	_item = item


func perform() -> bool:
	if not is_instance_valid(_item):
		return false

	var inventory: InventoryComponent = entity.inventory_component
	var equipment: EquipmentComponent = entity.equipment_component

	if inventory == null or equipment == null:
		return false

	if not inventory.items.has(_item):
		return false

	if _item.equippable_component == null:
		return false

	equipment.toggle_equip(_item)
	return true
