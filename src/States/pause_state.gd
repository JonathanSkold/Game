class_name PauseState
extends BaseState


func handle_input(event: InputEvent) -> Action:
	if pressed(event, "ui_back"):
		state_stack.pop()

	return null
