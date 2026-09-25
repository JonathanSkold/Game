class_name HistoryState
extends BaseState

const scroll_step = 16

@export var message_panel: PanelContainer
@export var message_log: MessageLog

func enter() -> void:
	message_panel.self_modulate = Color.RED

func exit() -> void:
	message_panel.self_modulate = Color.WHITE

func get_action() -> Action:
	var action: Action
	
	if Input.is_action_just_pressed("move_up"):
		message_log.scroll_vertical -= scroll_step
	elif Input.is_action_just_pressed("move_down"):
		message_log.scroll_vertical += scroll_step
	elif Input.is_action_just_pressed("move_left"):
		message_log.scroll_vertical = 0
	elif Input.is_action_just_pressed("move_right"):
		message_log.scroll_vertical = message_log.get_v_scroll_bar().max_value
	
	if Input.is_action_just_pressed("view_history") or Input.is_action_just_pressed("ui_back"):
		state_stack.pop()
		return null
		
	return action
