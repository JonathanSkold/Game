class_name PauseState
extends BaseState

func get_action() -> Action:
	if Input.is_action_just_pressed("ui_cancel"):
		state_stack.pop()
	
	return null
