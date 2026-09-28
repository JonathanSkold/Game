class_name SwapAction
extends Action

var _attached_item: Entity
var _backpack_item: Entity


func _init(
	entity: Entity,
	attached_item: Entity,
	backpack_item: Entity
) -> void:
	super._init(entity)
	_attached_item = attached_item
	_backpack_item = backpack_item


func perform() -> bool:
	var attachment: AttachmentComponent = entity.attachment_component

	if attachment == null:
		return false

	return attachment.swap_with_inventory(
		_attached_item,
		_backpack_item
	)
