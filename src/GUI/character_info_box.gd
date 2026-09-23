extends HBoxContainer

var _player: Entity

@onready var attack_label: Label = $AttackLabel
@onready var defense_label: Label = $DefenseLabel


func setup(player: Entity) -> void:
	_player = player
	_player.equipment_component.equipment_changed.connect(update_labels)
	update_labels()


func update_labels() -> void:
	if not _player.is_inside_tree():
		await _player.ready
	attack_label.text = "ATK: %d" % _player.fighter_component.power
	defense_label.text = "DEF: %d" % _player.fighter_component.defense
