class_name EscapeAction
extends Action


func perform() -> bool:
	SignalBus.escape_requested.emit()
	return false
