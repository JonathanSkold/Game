class_name DebugOverlay
extends CanvasLayer

@export var state_stack: StateStack

@export_group("Display")
@export var enabled: bool = true
@export var show_state_stack: bool = true

@onready var output: Label = $PanelContainer/MarginContainer/Label


func _process(_delta: float) -> void:
	visible = enabled

	if not enabled:
		return

	var sections := PackedStringArray()

	if show_state_stack:
		sections.append(_get_state_stack_text())

	var new_text: String = "\n\n".join(sections)

	visible = not sections.is_empty()

	if output.text != new_text:
		output.text = new_text


func _get_state_stack_text() -> String:
	if not is_instance_valid(state_stack):
		return "State stack: not assigned"

	var lines := PackedStringArray()

	for index in range(state_stack.states.size()):
		var state: BaseState = state_stack.states[index]
		var marker: String = ""

		lines.append("%s%s" % [state.name, marker])

	return "\n".join(lines)
