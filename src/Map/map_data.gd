class_name MapData
extends RefCounted

signal entity_placed(entity)

const entity_pathfinding_weight = 10.0

var width: int
var height: int
var tiles: Array[Tile]
var entities: Array[Entity]
var player: Entity
var down_stairs_location: Vector2i
var current_floor: int = 0
var pathfinder: AStarGrid2D

const MAX_SAVE_MAP_DIMENSION := 512

func get_save_data() -> Dictionary:
	var save_data := {
		"width": width,
		"height": height,
		"player": player.get_save_data(),
		"entities": [],
		"tiles": [],
		"current_floor": current_floor,
		"down_stairs_location": {"x": down_stairs_location.x, "y": down_stairs_location.y},
	}
	for entity in entities:
		if entity == player:
			continue
		save_data["entities"].append(entity.get_save_data())
	for tile in tiles:
		save_data["tiles"].append(tile.get_save_data())
	return save_data

static func validate_save_data(data: Variant) -> String:
	if not data is Dictionary:
		return "Map data must be a dictionary."

	for field in ["width", "height"]:
		if not SaveChecks.is_integer(data.get(field)):
			return "%s must be a whole number." % field

		if data[field] < 1 or data[field] > MAX_SAVE_MAP_DIMENSION:
			return "%s must be between 1 and %d." % [
				field,
				MAX_SAVE_MAP_DIMENSION,
			]

	var map_width := int(data["width"])
	var map_height := int(data["height"])

	if not SaveChecks.is_integer(data.get("current_floor")):
		return "current_floor must be a whole number."

	if data["current_floor"] < 1:
		return "current_floor must be at least 1."

	if not data.get("tiles") is Array:
		return "tiles must be an array."

	var saved_tiles: Array = data["tiles"]

	if saved_tiles.size() != map_width * map_height:
		return "Tile count does not match map dimensions."

	for index in range(saved_tiles.size()):
		var error := Tile.validate_save_data(saved_tiles[index])

		if not error.is_empty():
			return "tiles[%d]: %s" % [index, error]

	var stairs_error := _validate_saved_position(
		data.get("down_stairs_location"),
		map_width,
		map_height
	)

	if not stairs_error.is_empty():
		return "down_stairs_location: %s" % stairs_error

	var stairs: Dictionary = data["down_stairs_location"]
	var stairs_index := int(stairs["y"]) * map_width + int(stairs["x"])

	if saved_tiles[stairs_index]["key"] != "down_stairs":
		return "Stair location does not contain a down_stairs tile."

	var player_error := _validate_world_entity(
		data.get("player"),
		map_width,
		map_height,
		saved_tiles
	)

	if not player_error.is_empty():
		return "player: %s" % player_error

	if data["player"]["key"] != "player":
		return "The saved player must use the player definition."

	if not data.get("entities") is Array:
		return "entities must be an array."

	var saved_entities: Array = data["entities"]

	for index in range(saved_entities.size()):
		var entity_data: Variant = saved_entities[index]

		var error := _validate_world_entity(
			entity_data,
			map_width,
			map_height,
			saved_tiles
		)

		if not error.is_empty():
			return "entities[%d]: %s" % [index, error]

		if entity_data["key"] == "player":
			return "The player must not also appear in entities."

	return ""

static func _validate_saved_position(data: Variant, map_width: int, map_height: int) -> String:
	if not data is Dictionary:
		return "Position must be a dictionary."

	for coordinate in ["x", "y"]:
		if not SaveChecks.is_integer(data.get(coordinate)):
			return "%s must be a whole number." % coordinate

	# Check bounds before converting to integer coordinates.
	if data["x"] < 0 or data["x"] >= map_width:
		return "Position is outside the map horizontally."

	if data["y"] < 0 or data["y"] >= map_height:
		return "Position is outside the map vertically."

	return ""

static func _validate_world_entity(data: Variant, map_width: int, map_height: int, saved_tiles: Array) -> String:
	var error := Entity.validate_save_data(data)

	if not error.is_empty():
		return error

	error = _validate_saved_position(data, map_width, map_height)

	if not error.is_empty():
		return error

	var tile_index := int(data["y"]) * map_width + int(data["x"])
	var tile_key: String = saved_tiles[tile_index]["key"]
	var definition: TileDefinition = Tile.tile_types[tile_key]

	if not definition.is_walkable:
		return "World entity must be on a walkable tile."

	return ""

# Requires validated data and an empty MapData created with dimensions 0, 0.
func restore_save_data(data: Dictionary) -> void:
	assert(tiles.is_empty(), "Restore requires an empty map.")
	assert(entities.is_empty(), "Restore requires no existing entities.")
	assert(player != null, "Restore requires a fresh player Entity.")

	width = int(data["width"])
	height = int(data["height"])
	current_floor = int(data["current_floor"])

	var stairs: Dictionary = data["down_stairs_location"]
	down_stairs_location = Vector2i(
		int(stairs["x"]),
		int(stairs["y"])
	)

	_setup_tiles()

	var saved_tiles: Array = data["tiles"]

	for index in range(tiles.size()):
		tiles[index].restore_save_data(saved_tiles[index])

	player.map_data = self
	player.restore_save_data(data["player"])
	entities.append(player)

	for entity_data in data["entities"]:
		var restored_entity := Entity.create(self, Vector2i.ZERO, "")
		restored_entity.restore_save_data(entity_data)
		entities.append(restored_entity)

	# Every entity now has its final position and blocking state.
	setup_pathfinding()


func _init(map_width: int, map_height: int, player: Entity) -> void:
	width = map_width
	height = map_height
	self.player = player
	entities = []
	_setup_tiles()
	
func _setup_tiles() -> void:
	tiles = []
	for y in height:
		for x in width:
			var tile_position := Vector2i(x, y)
			var tile := Tile.new(tile_position, "wall")
			tiles.append(tile)
			
func get_tile(grid_position: Vector2i) -> Tile:
	var tile_index: int = grid_to_index(grid_position)
	if tile_index == -1:
		return null
	return tiles[tile_index]

func get_items() -> Array[Entity]:
	var items: Array[Entity] = []
	for entity in entities:
		if entity.consumable_component != null or entity.attachable_component != null:
			items.append(entity)
	return items

func grid_to_index(grid_position: Vector2i) -> int:
	if not is_in_bounds(grid_position):
		return -1
	return grid_position.y * width + grid_position.x

func is_in_bounds(coordinate: Vector2i) -> bool:
	return (
		0 <= coordinate.x
		and coordinate.x < width
		and 0 <= coordinate.y
		and coordinate.y < height
	)

func get_tile_xy(x: int, y: int) -> Tile:
	var grid_position := Vector2i(x, y)
	return get_tile(grid_position)

func get_blocking_entity_at_location(grid_position: Vector2i) -> Entity:
	for entity in entities:
		if entity.is_blocking_movement() and entity.grid_position == grid_position:
			return entity
	return null

func register_blocking_entity(entity: Entity) -> void:
	pathfinder.set_point_weight_scale(entity.grid_position, entity_pathfinding_weight)

func unregister_blocking_entity(entity: Entity) -> void:
	pathfinder.set_point_weight_scale(entity.grid_position, 0)
	
func setup_pathfinding() -> void:
	pathfinder = AStarGrid2D.new()
	pathfinder.region = Rect2i(0, 0, width, height)
	pathfinder.update()
	for y in height:
		for x in width:
			var grid_position := Vector2i(x, y)
			var tile: Tile = get_tile(grid_position)
			pathfinder.set_point_solid(grid_position, not tile.is_walkable())
	for entity in entities:
		if entity.is_blocking_movement():
			register_blocking_entity(entity)

func get_actors() -> Array[Entity]:
	var actors: Array[Entity] = []
	for entity in entities:
		if entity.is_alive():
			actors.append(entity)
	return actors

func get_actor_at_location(location: Vector2i) -> Entity:
	for actor in get_actors():
		if actor.grid_position == location:
			return actor
	return null

func find_drop_position(start: Vector2i) -> Vector2i:
	if not _is_drop_floor(start):
		return Vector2i(-1, -1)

	var occupied: Dictionary = {}

	for item in get_items():
		occupied[item.grid_position] = true

	var visited: Dictionary = {}
	visited[start] = true

	var queue: Array[Vector2i] = [start]
	var next_index: int = 0

	while next_index < queue.size():
		var position: Vector2i = queue[next_index]
		next_index += 1

		if not occupied.has(position):
			return position

		for direction in Grid.DIRECTIONS.values():
			var offset: Vector2i = direction
			var neighbor: Vector2i = position + offset

			if visited.has(neighbor):
				continue

			if not _is_drop_floor(neighbor):
				continue

			visited[neighbor] = true
			queue.append(neighbor)

	return Vector2i(-1, -1)


func _is_drop_floor(position: Vector2i) -> bool:
	var tile: Tile = get_tile(position)
	return tile != null and tile.is_walkable()
