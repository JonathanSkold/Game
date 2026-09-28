class_name AttachFromGroundAction
extends Action


func perform() -> bool:
	var attachment: AttachmentComponent = entity.attachment_component

	if attachment == null:
		return false

	var map_data: MapData = get_map_data()

	if map_data == null:
		return false

	for item in map_data.get_items():
		if item.grid_position == entity.grid_position:
			return attachment.attach_from_ground(item)

	MessageLog.send_message(
		"There is nothing here to attach.",
		GameColors.IMPOSSIBLE
	)
	return false
