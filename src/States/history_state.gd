class_name HistoryState
extends BaseState

const scroll_step = 16

@export var message_panel: PanelContainer
@export var message_log: MessageLog


func enter() -> void:
	message_panel.self_modulate = Color.RED

func exit() -> void:
	message_panel.self_modulate = Color.WHITE

func handle_input(event: InputEvent) -> Action:
	if pressed(event, "view_history") or pressed(event, "ui_back"):
		state_stack.pop()
		return null

	if pressed(event, "move_up"):
		message_log.scroll_vertical -= scroll_step
	
	elif pressed(event, "move_down"):
		message_log.scroll_vertical += scroll_step
	
	elif pressed(event, "move_left"):
		message_log.scroll_vertical = 0
	
	elif pressed(event, "move_right"):
		message_log.scroll_vertical = message_log.get_v_scroll_bar().max_value

	return null
