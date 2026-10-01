class_name Tile
extends Sprite2D

var _definition: TileDefinition

const tile_types = {
	"floor": preload("res://assets/definitions/tiles/tile_definition_floor.tres"),
	"wall": preload("res://assets/definitions/tiles/tile_definition_wall.tres"),
	"down_stairs": preload("res://assets/definitions/tiles/tile_definition_down_stairs.tres"),
}

var key: String

func get_save_data() -> Dictionary:
	return {
		"key": key,
		"is_explored": is_explored,
	}


static func validate_save_data(data: Variant) -> String:
	if not data is Dictionary:
		return "Tile data must be a dictionary."

	var saved_key: Variant = data.get("key")

	if not saved_key is String:
		return "Tile key must be a string."

	if not tile_types.has(saved_key):
		return "Unknown tile key: %s." % saved_key

	if not data.get("is_explored") is bool:
		return "Tile is_explored must be a boolean."

	return ""


# Requires data that has passed validation.
func restore_save_data(data: Dictionary) -> void:
	set_tile_type(data["key"])

	# Current visibility is recalculated by FOV after loading.
	is_in_view = false
	is_explored = data["is_explored"]
	visible = is_explored


var is_explored: bool = false:
	set(value):
		is_explored = value
		if is_explored and not visible:
			visible = true

var is_in_view: bool = false:
	set(value):
		is_in_view = value
		modulate = _definition.color_lit if is_in_view else _definition.color_dark
		if is_in_view and not is_explored:
			is_explored = true

func _init(grid_position: Vector2i, key: String) -> void:
	visible = false
	centered = false
	position = Grid.grid_to_world(grid_position)
	set_tile_type(key)


func set_tile_type(key: String) -> void:
	self.key = key
	_definition = tile_types[key]
	texture = _definition.texture
	modulate = _definition.color_dark
	
	material = _definition.material


func is_walkable() -> bool:
	return _definition.is_walkable


func is_transparent() -> bool:
	return _definition.is_transparent
