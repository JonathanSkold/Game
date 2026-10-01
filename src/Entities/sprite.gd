@tool
extends Sprite2D


func _ready() -> void:
	texture_changed.connect(_update_outline_region)
	_update_outline_region()


func _update_outline_region() -> void:
	if texture == null:
		return

	var atlas_texture := texture as AtlasTexture
	var source_region: Rect2

	if atlas_texture:
		source_region = atlas_texture.region
	else:
		source_region = Rect2(Vector2.ZERO, texture.get_size())

	set_instance_shader_parameter(
		"atlas_region",
		Vector4(
			source_region.position.x,
			source_region.position.y,
			source_region.size.x,
			source_region.size.y
		)
	)
