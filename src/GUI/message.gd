class_name Message
extends Label

var plain_text: String

var count: int = 1:
	set(value):
		count = value
		text = full_text()


func _init(msg_text: String, foreground_color: Color) -> void:
	plain_text = msg_text
	text = plain_text

	add_theme_color_override("font_color", foreground_color)
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func full_text() -> String:
	if count > 1:
		return "%s (x%d)" % [plain_text, count]

	return plain_text
