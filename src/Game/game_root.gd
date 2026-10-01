class_name GameRoot
extends Control

signal main_menu_requested

@onready var game: Game = $"%Game"
@onready var interface_layout: Control = $HBoxContainer
@onready var left_column: Control = $HBoxContainer/VBoxContainer

@onready var world_container: SubViewportContainer = $HBoxContainer/VBoxContainer/SubViewportContainer

@onready var info_bar: Control = $HBoxContainer/VBoxContainer/InfoBar

@onready var stats_panel: PanelContainer = $HBoxContainer/VBoxContainer/InfoBar/StatsPanel

@onready var message_panel: PanelContainer = $HBoxContainer/VBoxContainer/InfoBar/MessagePanel

@onready var inventory_panel: InventoryPanel = $HBoxContainer/InventoryPanel

@onready var attached_box: PanelContainer = %AttachedBox
@onready var inventory_box: PanelContainer = %InventoryBox
@export_range(0.1, 0.9, 0.01) var attached_fraction: float = 0.5

@export_range(1, 6, 1) var cell_scale: int = 3
@export_range(0.1, 0.5, 0.01) var sidebar_fraction: float = 0.2
@export_range(0.1, 0.5, 0.01) var bottom_fraction: float = 0.17
@export_range(0.1, 0.9, 0.01) var stats_fraction: float = 0.5

@export var ui_font: Font = preload(
	"res://assets/Fonts/kenney_kenney-fonts/Fonts/Kenney Pixel.ttf"
)

var ui_theme := Theme.new()

const CELL_FRAME_TEXTURE: Texture2D = preload(
	"res://assets/tilesheets/cell_frame.png"
)

var _frame_cell_size: int = 0

@export_range(8, 24, 1) var base_font_size: int = 16

const BASE_CELL_SIZE := 16

var display_cell_size: int
var screen_cells: Vector2i
var grid_rect: Rect2i

var cell_panel_style := StyleBoxTexture.new()
@export var panel_frame_color: Color = Color.DIM_GRAY

func new_game() -> void:
	game.new_game()

func load_game() -> void:
	if not game.load_game():
		game.new_game()

func _ready() -> void:
	SignalBus.escape_requested.connect(_on_escape_requested)

	interface_layout.theme = ui_theme
	ui_theme.set_color("font_color", "Label", Color.WHITE)

	_setup_panel_styles()
	get_viewport().size_changed.connect(_update_display_layout)
	_update_display_layout()

	load_game()

func _on_escape_requested() -> void:
	save_and_quit()

func save_and_quit() -> void:
	var result := game.save_game()

	if not result.succeeded():
		MessageLog.send_message(
			"Could not save: %s" % result.message,
			GameColors.IMPOSSIBLE
		)
		push_warning(result.message)
		return

	get_tree().quit()

func _update_display_layout() -> void:
	var window_size := Vector2i(get_viewport().get_visible_rect().size)
	calculate_grid_layout(window_size)
	_update_font_size()
	_update_panel_insets()

	interface_layout.position = Vector2(grid_rect.position)
	interface_layout.size = Vector2(grid_rect.size)
	_layout_panels()

	# Original tiles remain 16 × 16 world units.
	# A scale of 2 displays them at 32 × 32 window pixels.
	game.camera.zoom = Vector2.ONE * float(cell_scale)


func calculate_grid_layout(window_size: Vector2i) -> void:
	display_cell_size = BASE_CELL_SIZE * cell_scale

	screen_cells = Vector2i(
		floori(float(window_size.x) / display_cell_size),
		floori(float(window_size.y) / display_cell_size)
	)

	var occupied_size := screen_cells * display_cell_size
	var unused_size := window_size - occupied_size

	var origin := Vector2i(
		floori(unused_size.x / 2.0),
		floori(unused_size.y / 2.0)
	)

	grid_rect = Rect2i(origin, occupied_size)

func _place_in_cells(
	control: Control,
	cell_position: Vector2i,
	cell_size: Vector2i
) -> void:
	# Positions are relative to this control's parent.
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = Vector2(cell_position * display_cell_size)
	control.size = Vector2(cell_size * display_cell_size)

func _layout_panels() -> void:
	# Only prevents invalid arithmetic for extremely small windows.
	# A proper minimum supported window size comes later.
	if screen_cells.x < 3 or screen_cells.y < 2:
		return

	var sidebar_columns := clampi(
		roundi(screen_cells.x * sidebar_fraction),
		1,
		screen_cells.x - 2
	)
	var left_columns := screen_cells.x - sidebar_columns

	var bottom_rows := clampi(
		roundi(screen_cells.y * bottom_fraction),
		1,
		screen_cells.y - 1
	)
	var map_rows := screen_cells.y - bottom_rows

	var stats_columns := clampi(
		roundi(left_columns * stats_fraction),
		1,
		left_columns - 1
	)
	var message_columns := left_columns - stats_columns

	_place_in_cells(
		left_column,
		Vector2i.ZERO,
		Vector2i(left_columns, screen_cells.y)
	)

	_place_in_cells(
		inventory_panel,
		Vector2i(left_columns, 0),
		Vector2i(sidebar_columns, screen_cells.y)
	)

	_place_in_cells(
		world_container,
		Vector2i.ZERO,
		Vector2i(left_columns, map_rows)
	)

	_place_in_cells(
		info_bar,
		Vector2i(0, map_rows),
		Vector2i(left_columns, bottom_rows)
	)

	_place_in_cells(
		stats_panel,
		Vector2i.ZERO,
		Vector2i(stats_columns, bottom_rows)
	)

	_place_in_cells(
		message_panel,
		Vector2i(stats_columns, 0),
		Vector2i(message_columns, bottom_rows)
	)
	
	var attached_rows := clampi(
		roundi(screen_cells.y * attached_fraction),
		1,
		screen_cells.y - 1
	)
	var inventory_rows := screen_cells.y - attached_rows

	_place_in_cells(
		attached_box,
		Vector2i.ZERO,
		Vector2i(sidebar_columns, attached_rows)
	)

	_place_in_cells(
		inventory_box,
		Vector2i(0, attached_rows),
		Vector2i(sidebar_columns, inventory_rows)
	)

func _update_font_size() -> void:
	ui_theme.default_font = ui_font
	ui_theme.default_font_size = base_font_size * cell_scale

func _setup_panel_styles() -> void:
	cell_panel_style.modulate_color = panel_frame_color
	cell_panel_style.axis_stretch_horizontal = \
		StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	cell_panel_style.axis_stretch_vertical = \
		StyleBoxTexture.AXIS_STRETCH_MODE_TILE

	ui_theme.set_type_variation("CellPanel", "PanelContainer")
	ui_theme.set_stylebox("panel", "CellPanel", cell_panel_style)

func _update_panel_insets() -> void:
	if _frame_cell_size == display_cell_size:
		return

	var frame_image := CELL_FRAME_TEXTURE.get_image()

	# The source contains three cells across and three down.
	var frame_size := display_cell_size * 3
	frame_image.resize(
		frame_size,
		frame_size,
		Image.INTERPOLATE_NEAREST
	)

	cell_panel_style.texture = ImageTexture.create_from_image(frame_image)

	# One displayed cell for each corner and border strip.
	cell_panel_style.set_texture_margin_all(float(display_cell_size))

	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		cell_panel_style.set_content_margin(
			side,
			float(display_cell_size)
		)

	_frame_cell_size = display_cell_size
