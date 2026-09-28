class_name InventoryComponent
extends Component

var items: Array[Entity]
var capacity: int

signal inventory_changed

func get_save_data() -> Dictionary:
	var save_data: Dictionary = {
		"capacity": capacity,
		"items": []
	}
	for item in items:
		save_data["items"].append(item.get_save_data())
	return save_data

func restore(save_data: Dictionary) -> void:
	for item_data in save_data["items"]:
		var item: Entity = Entity.create(null, Vector2i(-1, -1), "")
		item.restore(item_data)
		items.append(item)
	
	inventory_changed.emit()

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

	# A destination exists. Complete the logical transfer first.
	items.erase(item)
	item.map_data = map_data
	item.grid_position = destination
	map_data.entities.append(item)

	# Then restore its world presentation.
	map_data.entity_placed.emit(item)

	inventory_changed.emit()

	MessageLog.send_message(
		"You dropped the %s." % item.get_entity_name(),
		Color.WHITE
	)
	return true
