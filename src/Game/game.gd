class_name Game
extends Node2D

signal player_created(player)

@onready var player: Entity
@onready var map: Map = $Map
@onready var camera: Camera2D = $Camera2D

@onready var state_stack: StateStack = $StateStack


func new_game() -> void:
	assert(player == null, "Start a run only once per Game instance.")

	player = Entity.create(null, Vector2i.ZERO, "player")
	map.generate(player)

	_finish_startup(
		"Hello and welcome, adventurer, to yet another dungeon!"
	)


func load_game() -> bool:
	assert(player == null, "Start a run only once per Game instance.")

	var result := SaveSystem.load_save()

	if not result.succeeded():
		if result.status != SaveResult.Status.NOT_FOUND:
			push_warning("Could not load saved game: %s" % result.message)

		return false

	if not result.message.is_empty():
		push_warning(result.message)

	# No nodes are created until reading and validation succeed.
	player = Entity.create(null, Vector2i.ZERO, "")
	map.restore_save_data(result.data, player)

	_finish_startup("Welcome back, adventurer!")
	return true


func _finish_startup(welcome_message: String) -> void:
	camera.get_parent().remove_child(camera)
	player.visual.add_child(camera)
	camera.position = Vector2.ZERO

	map.update_fov(player.grid_position)

	state_stack.player = player

	# UI reads the completed player, including restored items and stats.
	player_created.emit(player)

	state_stack.start()

	MessageLog.send_message.bind(
		welcome_message,
		GameColors.WELCOME_TEXT
	).call_deferred()

	camera.make_current.call_deferred()

func save_game() -> SaveResult:
	if map.map_data == null:
		return SaveResult.new(
			SaveResult.Status.INVALID_DATA,
			{},
			"There is no active game to save."
		)

	return SaveSystem.write_save(map.map_data.get_save_data())

func get_map_data() -> MapData:
	return map.map_data


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	if not event.pressed or event.echo:
		return

	if state_stack.current() == null:
		return

	get_viewport().set_input_as_handled()

	var action: Action = state_stack.handle_input(event)
	execute_action(action)


func execute_action(action: Action) -> void:
	if action == null:
		return

	if action.perform():
		_handle_enemy_turns()
		map.update_fov(player.grid_position)

func _handle_enemy_turns() -> void:
	for entity in get_map_data().get_actors():
		if entity == player or not entity.is_alive():
			continue

		if entity.ai_controller != null:
			entity.ai_controller.perform()
