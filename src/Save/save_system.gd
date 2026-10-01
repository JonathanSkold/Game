class_name SaveSystem
extends RefCounted

const SAVE_PATH := "user://saves/save_game.json"
const FORMAT_VERSION := 1


static func load_save(path: String = SAVE_PATH) -> SaveResult:
	var primary := read_save(path)

	if primary.succeeded():
		return primary

	var backup := read_save(path + ".bak")

	if backup.succeeded():
		backup.message = "Loaded the backup because the main save was unavailable."
		return backup

	if (
		primary.status == SaveResult.Status.NOT_FOUND
		and backup.status != SaveResult.Status.NOT_FOUND
	):
		return backup

	return primary

static func read_save(path: String = SAVE_PATH) -> SaveResult:
	if not FileAccess.file_exists(path):
		return SaveResult.new(
			SaveResult.Status.NOT_FOUND,
			{},
			"No save file exists."
		)

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		return SaveResult.new(
			SaveResult.Status.IO_ERROR,
			{},
			"Could not open save: %s" % error_string(
				FileAccess.get_open_error()
			)
		)

	var text := file.get_as_text()
	var read_error := file.get_error()
	file.close()

	if read_error != OK and read_error != ERR_FILE_EOF:
		return SaveResult.new(
			SaveResult.Status.IO_ERROR,
			{},
			"Could not read save: %s" % error_string(read_error)
		)

	return decode_save(text)

static func decode_save(text: String) -> SaveResult:
	var json := JSON.new()
	var parse_error := json.parse(text)

	if parse_error != OK:
		return SaveResult.new(
			SaveResult.Status.INVALID_DATA,
			{},
			"Invalid JSON at line %d: %s" % [
				json.get_error_line(),
				json.get_error_message(),
			]
		)

	if not json.data is Dictionary:
		return SaveResult.new(
			SaveResult.Status.INVALID_DATA,
			{},
			"Save root must be a dictionary."
		)

	var document: Dictionary = json.data
	var version: Variant = document.get("format_version")

	if not (version is int or version is float):
		return SaveResult.new(
			SaveResult.Status.INVALID_DATA,
			{},
			"Save format version is missing or invalid."
		)

	if version != FORMAT_VERSION:
		return SaveResult.new(
			SaveResult.Status.UNSUPPORTED_VERSION,
			{},
			"Unsupported save format version: %s" % str(version)
		)

	if not document.get("game") is Dictionary:
		return SaveResult.new(
			SaveResult.Status.INVALID_DATA,
			{},
			"Save game data must be a dictionary."
		)

	var game_data: Dictionary = document["game"]
	var validation_error := MapData.validate_save_data(game_data)

	if not validation_error.is_empty():
		return SaveResult.new(
			SaveResult.Status.INVALID_DATA,
			{},
			validation_error
		)

	return SaveResult.new(
		SaveResult.Status.OK,
		game_data
	)

static func write_save(game_data: Dictionary,path: String = SAVE_PATH) -> SaveResult:
	var validation_error := MapData.validate_save_data(game_data)

	if not validation_error.is_empty():
		return SaveResult.new(
			SaveResult.Status.INVALID_DATA,
			{},
			validation_error
		)

	var document := {
		"format_version": FORMAT_VERSION,
		"game": game_data,
	}

	var temporary_path := path + ".tmp"
	var backup_path := path + ".bak"

	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(path.get_base_dir())
	)

	if directory_error != OK:
		return _io_failure(
			"Could not create save directory",
			directory_error
		)

	var file := FileAccess.open(temporary_path, FileAccess.WRITE)

	if file == null:
		return _io_failure(
			"Could not open temporary save",
			FileAccess.get_open_error()
		)

	file.store_string(JSON.stringify(document))
	var write_error := file.get_error()
	file.flush()
	var flush_error := file.get_error()
	file.close()

	if write_error != OK:
		return _io_failure("Could not write save", write_error)

	if flush_error != OK:
		return _io_failure("Could not flush save", flush_error)

	# Check the actual file before replacing the current save.
	var verification := read_save(temporary_path)

	if not verification.succeeded():
		return SaveResult.new(
			verification.status,
			{},
			"Temporary save verification failed: %s" % verification.message
		)

	# Only replace the backup with a valid previous save.
	var previous := read_save(path)

	if previous.status == SaveResult.Status.IO_ERROR:
		return previous

	if previous.succeeded():
		var backup_error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(path),
			ProjectSettings.globalize_path(backup_path)
		)

		if backup_error != OK:
			return _io_failure("Could not back up previous save", backup_error)

	var replace_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(path)
	)

	if replace_error != OK:
		return _io_failure("Could not replace save", replace_error)

	return SaveResult.new(SaveResult.Status.OK)

static func _io_failure(operation: String, error: Error) -> SaveResult:
	return SaveResult.new(
		SaveResult.Status.IO_ERROR,
		{},
		"%s: %s" % [operation, error_string(error)]
	)
