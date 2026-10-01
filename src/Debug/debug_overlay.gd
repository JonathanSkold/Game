class_name DebugOverlay
extends CanvasLayer

@export var game_root: GameRoot
@export var state_stack: StateStack

@export_group("Display")
@export var enabled: bool = true
@export var show_layout: bool = true
@export var show_state_stack: bool = true

@onready var output: Label = $PanelContainer/MarginContainer/Label


func _process(_delta: float) -> void:
	visible = enabled

	if not enabled:
		return

	var sections := PackedStringArray()
	
	if show_layout:
		sections.append(_get_layout_text())
		
	if show_state_stack:
		sections.append(_get_state_stack_text())

	var new_text: String = "\n\n".join(sections)

	visible = not sections.is_empty()

	if output.text != new_text:
		output.text = new_text


func _get_layout_text() -> String:
	if not is_instance_valid(game_root):
		return "Layout: GameRoot not assigned"

	if game_root.display_cell_size <= 0:
		return "Layout: waiting for initialization"

	var window_size := Vector2i(
		game_root.get_viewport().get_visible_rect().size
	)
	var cell_size := game_root.display_cell_size

	var lines := PackedStringArray([
		"Layout",
		"Window: %d × %d px" % [window_size.x, window_size.y],
		"Cell: %d × %d px | Scale: %d" % [
			cell_size, cell_size, game_root.cell_scale
		],
		"Available grid: %d × %d cells" % [
			game_root.screen_cells.x,
			game_root.screen_cells.y
		],
		"Outer offset: %s px" % str(game_root.grid_rect.position),
		"Actual panel sizes:"
	])

	lines.append(_get_panel_size_text(
		"Interface", game_root.interface_layout, cell_size
	))
	lines.append(_get_panel_size_text(
		"Map", game_root.world_container, cell_size
	))
	lines.append(_get_panel_size_text(
		"Inventory", game_root.inventory_panel, cell_size
	))
	lines.append(_get_panel_size_text(
		"Bottom bar", game_root.info_bar, cell_size
	))
	lines.append(_get_panel_size_text(
		"Stats", game_root.stats_panel, cell_size
	))
	lines.append(_get_panel_size_text(
		"Messages", game_root.message_panel, cell_size
	))

	return "\n".join(lines)


func _get_panel_size_text(
	title: String,
	panel: Control,
	cell_size: int
) -> String:
	if not is_instance_valid(panel):
		return "%s: unavailable" % title

	var cells := panel.size / float(cell_size)
	var aligned := (
		is_equal_approx(cells.x, roundf(cells.x))
		and is_equal_approx(cells.y, roundf(cells.y))
	)
	var warning := "" if aligned else " [NOT WHOLE CELLS]"

	return "%s: %.2f × %.2f cells | %.0f × %.0f px%s" % [
		title,
		cells.x, cells.y,
		panel.size.x, panel.size.y,
		warning
	]


func _get_state_stack_text() -> String:
	if not is_instance_valid(state_stack):
		return "State stack: not assigned"

	var lines := PackedStringArray()

	for index in range(state_stack.states.size()):
		var state: BaseState = state_stack.states[index]
		var marker: String = ""

		lines.append("%s%s" % [state.name, marker])

	return "\n".join(lines)
