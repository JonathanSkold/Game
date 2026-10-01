class_name SaveChecks
extends RefCounted


static func is_integer(value: Variant) -> bool:
	if value is int:
		return true

	if value is float:
		return is_finite(value) and value == floor(value)

	return false
