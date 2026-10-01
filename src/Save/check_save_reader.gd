extends Node

var failures := 0
var restore_messages := 0
var restore_death_events := 0


func _ready() -> void:
	print("TEST: started")
	_run()
	print("TEST: finished")


func _run() -> void:
	var test_path := "user://save_test_%d.json" % Time.get_ticks_usec()
	print("Test save: ", ProjectSettings.globalize_path(test_path))

	var original := _create_test_world()
	var original_data := original.get_save_data()

	var write_result := SaveSystem.write_save(original_data, test_path)
	_check(write_result.succeeded(), "write save: " + write_result.message)

	if not write_result.succeeded():
		_free_test_world(original)
		_remove_test_files(test_path)
		_print_summary()
		return

	var read_result := SaveSystem.read_save(test_path)
	_check(
		read_result.succeeded(),
		"read and validate save: " + read_result.message
	)

	if not read_result.succeeded():
		_free_test_world(original)
		_remove_test_files(test_path)
		_print_summary()
		return

	var restored_player := Entity.create(null, Vector2i.ZERO, "")
	var restored := MapData.new(0, 0, restored_player)

	SignalBus.message_sent.connect(_on_restore_message)
	SignalBus.player_died.connect(_on_restore_death)

	restored.restore_save_data(read_result.data)

	SignalBus.message_sent.disconnect(_on_restore_message)
	SignalBus.player_died.disconnect(_on_restore_death)

	_check(
		restore_messages == 0 and restore_death_events == 0,
		"restoration emits no gameplay messages or player-death events"
	)

	_check(
		_same_data(original_data, restored.get_save_data()),
		"restored world preserves saved data"
	)

	_check_owned_items(restored_player, "player")
	_check_corpse(restored)
	_check_recovery(original_data, test_path)

	# Keep references to verify that freeing actors frees their items.
	var owned_items: Array[Entity] = []
	for actor in restored.entities:
		owned_items.append_array(actor.inventory_component.items)
		owned_items.append_array(
			actor.attachment_component.get_attached_items()
		)

	_free_test_world(original)
	_free_test_world(restored)

	var all_items_freed := true
	for item in owned_items:
		if is_instance_valid(item):
			all_items_freed = false

	_check(all_items_freed, "freeing actors frees their owned items")

	_remove_test_files(test_path)
	_print_summary()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		print("FAIL: ", description)
		push_error(description)


func _print_summary() -> void:
	if failures == 0:
		print("ALL SAVE/LOAD CHECKS PASSED")
	else:
		print("SAVE/LOAD CHECKS FAILED: ", failures)


func _same_data(first: Dictionary, second: Dictionary) -> bool:
	# Normalize both through JSON before comparing their contents.
	var normalized_first: Variant = JSON.parse_string(
		JSON.stringify(first)
	)
	var normalized_second: Variant = JSON.parse_string(
		JSON.stringify(second)
	)

	return normalized_first == normalized_second


func _on_restore_message(_text, _color) -> void:
	restore_messages += 1


func _on_restore_death() -> void:
	restore_death_events += 1


func _create_test_world() -> MapData:
	var player := Entity.create(null, Vector2i.ZERO, "player")
	var world := MapData.new(2, 2, player)

	player.map_data = world
	world.entities.append(player)
	world.current_floor = 1
	world.down_stairs_location = Vector2i(1, 1)

	for tile in world.tiles:
		tile.set_tile_type("floor")
		tile.is_explored = true

	world.get_tile(Vector2i(1, 1)).set_tile_type("down_stairs")

	player.fighter_component.hp = 17

	player.inventory_component.store_item(
		Entity.create(null, Vector2i.ZERO, "dagger")
	)
	player.attachment_component.store_item(
		Entity.create(null, Vector2i.ZERO, "leather_armor")
	)

	var enemy := Entity.create(world, Vector2i(1, 0), "orc")
	enemy.ai_controller.push(ConfusedEnemyAIComponent.new(5))
	enemy.ai_controller.push(ConfusedEnemyAIComponent.new(3))
	world.entities.append(enemy)

	var corpse := Entity.create(world, Vector2i(0, 1), "troll")

	# Test fixture only; enemy definitions remain unchanged.
	corpse.inventory_component.capacity = 1
	corpse.inventory_component.store_item(
		Entity.create(null, Vector2i.ZERO, "dagger")
	)
	corpse.attachment_component.store_item(
		Entity.create(null, Vector2i.ZERO, "sword")
	)

	corpse.fighter_component.hp = 0
	corpse.apply_dead_state()
	world.entities.append(corpse)

	world.setup_pathfinding()
	return world


func _check_owned_items(actor: Entity, description: String) -> void:
	var inventory_ok := true

	for item in actor.inventory_component.items:
		if (
			item.get_parent() != actor.inventory_component
			or item.visible
			or item.map_data != null
			or item.grid_position != Vector2i(-1, -1)
		):
			inventory_ok = false

	_check(inventory_ok, description + " inventory ownership and visibility")

	var attachments_ok := true

	for item in actor.attachment_component.get_attached_items():
		if (
			item.get_parent() != actor.attachment_component
			or item.visible
			or item.map_data != null
			or item.grid_position != Vector2i(-1, -1)
		):
			attachments_ok = false

	_check(
		attachments_ok,
		description + " attachment ownership and visibility"
	)


func _check_corpse(world: MapData) -> void:
	# Fixture order: player, live enemy, corpse.
	var corpse: Entity = world.entities[2]

	_check(
		corpse.type == Entity.EntityType.CORPSE
		and corpse.fighter_component.hp == 0
		and not corpse.is_alive()
		and not corpse.blocks_movement,
		"corpse restores dead, non-blocking state"
	)

	_check(
		corpse.ai_controller.current() == null,
		"corpse has no active AI"
	)

	_check(
		corpse.inventory_component.items.size() == 1
		and corpse.attachment_component.get_attached_items().size() == 1,
		"corpse retains inventory and attached items"
	)

	_check_owned_items(corpse, "corpse")

	_check(
		world.pathfinder.get_point_weight_scale(
			corpse.grid_position
		) == 1.0,
		"restored corpse does not add a blocking pathfinding weight"
	)


func _check_recovery(data: Dictionary, path: String) -> void:
	_check(
		SaveSystem.load_save(path + ".missing").status
		== SaveResult.Status.NOT_FOUND,
		"missing primary and backup report NOT_FOUND"
	)

	_check(
		SaveSystem.decode_save(
			'{"format_version":999,"game":{}}'
		).status == SaveResult.Status.UNSUPPORTED_VERSION,
		"unsupported format version is rejected"
	)

	var second_data: Dictionary = data.duplicate(true)
	second_data["player"]["fighter_component"]["hp"] = 11

	var second_write := SaveSystem.write_save(second_data, path)
	_check(second_write.succeeded(), "second save succeeds")

	if not second_write.succeeded():
		print(second_write.message)
		return

	var primary := SaveSystem.read_save(path)
	_check(primary.succeeded(), "updated primary can be read")

	if primary.succeeded():
		_check(
			_same_data(primary.data, second_data),
			"primary contains the latest snapshot"
		)

	var backup := SaveSystem.read_save(path + ".bak")
	_check(backup.succeeded(), "backup can be read")

	if backup.succeeded():
		_check(
			_same_data(backup.data, data),
			"backup contains the previous snapshot"
		)

	var primary_before := FileAccess.get_file_as_bytes(path)
	var backup_before := FileAccess.get_file_as_bytes(path + ".bak")

	var invalid_data: Dictionary = data.duplicate(true)
	invalid_data["tiles"] = []

	var rejected := SaveSystem.write_save(invalid_data, path)

	_check(
		rejected.status == SaveResult.Status.INVALID_DATA,
		"invalid snapshot is rejected"
	)

	_check(
		FileAccess.get_file_as_bytes(path) == primary_before
		and FileAccess.get_file_as_bytes(path + ".bak") == backup_before,
		"rejected save leaves primary and backup unchanged"
	)

	# An existing file cannot also be a directory.
	var failed_write := SaveSystem.write_save(
		data,
		path + "/blocked.json"
	)

	_check(
		failed_write.status == SaveResult.Status.IO_ERROR,
		"file-write failure returns IO_ERROR"
	)

	_check(
		FileAccess.get_file_as_bytes(path) == primary_before
		and FileAccess.get_file_as_bytes(path + ".bak") == backup_before,
		"failed file operation leaves existing saves unchanged"
	)

	# Corrupt only this test's primary file.
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "test can open primary for corruption")

	if file == null:
		return

	file.store_string("{broken")
	file.close()

	_check(
		SaveSystem.read_save(path).status == SaveResult.Status.INVALID_DATA,
		"corrupt primary is rejected"
	)

	var recovered := SaveSystem.load_save(path)
	_check(recovered.succeeded(), "corrupt primary falls back to backup")

	if recovered.succeeded():
		_check(
			_same_data(recovered.data, data),
			"backup recovery returns the previous snapshot"
		)

	var remove_error := DirAccess.remove_absolute(
		ProjectSettings.globalize_path(path)
	)
	_check(remove_error == OK, "test primary removed")

	var missing_primary := SaveSystem.load_save(path)
	_check(
		missing_primary.succeeded(),
		"missing primary also falls back to backup"
	)

	if missing_primary.succeeded():
		_check(
			_same_data(missing_primary.data, data),
			"missing-primary recovery returns the backup snapshot"
		)


func _free_test_world(world: MapData) -> void:
	for entity in world.entities:
		entity.free()

	for tile in world.tiles:
		tile.free()

	world.entities.clear()
	world.tiles.clear()
	world.player = null
	world.pathfinder = null


func _remove_test_files(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var file_path: String = path + suffix

		if FileAccess.file_exists(file_path):
			var error := DirAccess.remove_absolute(
				ProjectSettings.globalize_path(file_path)
			)
			_check(error == OK, "remove test file: " + file_path)
