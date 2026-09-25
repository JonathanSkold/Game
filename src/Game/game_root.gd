class_name GameRoot
extends Control

signal main_menu_requested

@onready var game: Game = $"%Game"


func new_game() -> void:
	game.new_game()

func load_game() -> void:
	if not game.load_game():
		main_menu_requested.emit()

func _ready() -> void:
	SignalBus.escape_requested.connect(_on_escape_requested)
	new_game()

func _on_escape_requested() -> void:
	main_menu_requested.emit()
