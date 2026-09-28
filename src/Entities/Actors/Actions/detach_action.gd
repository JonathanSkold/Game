class_name DetachAction
extends Action

var _item: Entity


func _init(entity: Entity, item: Entity) -> void:
	super._init(entity)
	_item = item


func perform() -> bool:
	if not is_instance_valid(_item):
		return false

	var attachment: AttachmentComponent = entity.attachment_component

	if attachment == null:
		return false

	return attachment.detach(_item)
