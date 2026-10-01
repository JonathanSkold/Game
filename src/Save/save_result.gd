class_name SaveResult
extends RefCounted

enum Status {
	OK,
	NOT_FOUND,
	IO_ERROR,
	INVALID_DATA,
	UNSUPPORTED_VERSION,
}

var status: Status
var data: Dictionary
var message: String


func _init(
	result_status: Status,
	result_data: Dictionary = {},
	result_message: String = ""
) -> void:
	status = result_status
	data = result_data
	message = result_message


func succeeded() -> bool:
	return status == Status.OK
