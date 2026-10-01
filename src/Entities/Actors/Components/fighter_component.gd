class_name FighterComponent
extends Component

signal hp_changed(hp, max_hp)

var max_hp: int
var hp: int:
	set(value):
		hp = clampi(value, 0, max_hp)
var base_defense: int
var base_power: int
var defense: int: 
	get:
		return base_defense + get_defense_bonus()
var power: int: 
	get:
		return base_power + get_power_bonus()

var death_texture: Texture
var death_color: Color


func get_save_data() -> Dictionary:
	return {
		"max_hp": max_hp,
		"hp": hp,
		"power": base_power,
		"defense": base_defense,
	}

static func validate_save_data(data: Variant) -> String:
	if not data is Dictionary:
		return "Fighter data must be a dictionary."

	for field in ["max_hp", "hp", "power", "defense"]:
		if not SaveChecks.is_integer(data.get(field)):
			return "Fighter %s must be a whole number." % field

	if data["max_hp"] <= 0:
		return "Fighter max_hp must be greater than zero."

	if data["hp"] < 0 or data["hp"] > data["max_hp"]:
		return "Fighter hp must be between zero and max_hp."

	return ""

# Requires validated data.
func restore_save_data(data: Dictionary) -> void:
	max_hp = int(data["max_hp"])
	base_power = int(data["power"])
	base_defense = int(data["defense"])
	hp = int(data["hp"])


func _init(definition: FighterComponentDefinition) -> void:
	max_hp = definition.max_hp
	hp = definition.max_hp
	base_defense = definition.defense
	base_power = definition.power
	death_texture = definition.death_texture
	death_color = definition.death_color

func get_defense_bonus() -> int:
	if entity.attachment_component:
		return entity.attachment_component.get_defense_bonus()
	return 0


func get_power_bonus() -> int:
	if entity.attachment_component:
		return entity.attachment_component.get_power_bonus()
	return 0
	
func take_damage(amount: int) -> void:
	if amount <= 0 or hp <= 0:
		return

	hp -= amount

	if hp == 0:
		die()

	hp_changed.emit(hp, max_hp)


func heal(amount: int) -> int:
	if amount <= 0 or hp <= 0 or hp == max_hp:
		return 0

	var previous_hp := hp
	hp += mini(amount, max_hp - hp)

	var recovered := hp - previous_hp
	hp_changed.emit(hp, max_hp)

	return recovered

func die() -> void:
	if entity.type == Entity.EntityType.CORPSE:
		return

	var map_data: MapData = get_map_data()
	var was_player := map_data.player == entity
	var previous_name := entity.get_entity_name()

	hp = 0
	entity.apply_dead_state()
	map_data.unregister_blocking_entity(entity)

	if was_player:
		MessageLog.send_message(
			"You died!",
			GameColors.PLAYER_DIE
		)
		SignalBus.player_died.emit()
	else:
		MessageLog.send_message(
			"%s is dead!" % previous_name,
			GameColors.ENEMY_DIE
		)
