class_name InventoryComponent
extends Component

var items: Array[Entity]
var capacity: int

signal inventory_changed

func get_save_data() -> Dictionary:
	var saved_items: Array = []

	for item in items:
		saved_items.append(item.get_save_data())

	return {
		"capacity": capacity,
		"items": saved_items,
	}

static func validate_save_data(data: Variant, depth: int = 0) -> String:
	if not data is Dictionary:
		return "Inventory data must be a dictionary."

	if not SaveChecks.is_integer(data.get("capacity")):
		return "Inventory capacity must be a whole number."

	if data["capacity"] < 0:
		return "Inventory capacity cannot be negative."

	if not data.get("items") is Array:
		return "Inventory items must be an array."

	var saved_items: Array = data["items"]

	if saved_items.size() > data["capacity"]:
		return "Inventory contains more items than its capacity."

	for index in range(saved_items.size()):
		var item_data: Variant = saved_items[index]

		var error := Entity.validate_save_data(item_data, depth + 1)

		if not error.is_empty():
			return "Inventory items[%d]: %s" % [index, error]

		var definition: EntityDefinition = load(
			Entity.entity_types[item_data["key"]]
		)

		if definition.type != Entity.EntityType.ITEM:
			return "Inventory items[%d] is not an item." % index

	return ""


# Requires validated data and a fresh, empty inventory.
func restore_save_data(data: Dictionary) -> void:
	assert(items.is_empty(), "Restore requires an empty inventory.")

	capacity = int(data["capacity"])

	for item_data in data["items"]:
		var item := Entity.create(null, Vector2i.ZERO, "")
		item.restore_save_data(item_data)

		store_item(item)

func _init(capacity: int) -> void:
	items = []
	self.capacity = capacity

func is_full() -> bool:
	return items.size() >= capacity

func drop(item: Entity) -> bool:
	if not is_instance_valid(item) or not items.has(item):
		return false

	var map_data: MapData = get_map_data()

	if map_data == null:
		return false

	var destination: Vector2i = map_data.find_drop_position(
		entity.grid_position
	)

	if destination == Vector2i(-1, -1):
		MessageLog.send_message(
			"There is no room to drop that item.",
			GameColors.IMPOSSIBLE
		)
		return false

	release_item(item)

	item.map_data = map_data
	item.grid_position = destination
	map_data.entities.append(item)

	map_data.entity_placed.emit(item)
	item.visible = map_data.get_tile(destination).is_in_view

	inventory_changed.emit()

	MessageLog.send_message(
		"You dropped the %s." % item.get_entity_name(),
		Color.WHITE
	)
	return true

# Low-level storage operations: caller validates the transfer first.
# No gameplay notifications are emitted here.
func store_item(item: Entity, index: int = -1) -> void:
	assert(item.get_parent() == null)
	assert(not items.has(item))
	assert(not is_full())
	assert(index >= -1 and index <= items.size())

	if index == -1:
		items.append(item)
	else:
		items.insert(index, item)

	item.move_into_storage(self)


func release_item(item: Entity) -> void:
	assert(items.has(item))
	assert(item.get_parent() == self)

	items.erase(item)
	remove_child(item)
