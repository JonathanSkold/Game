class_name Entity
extends Node2D

const ENTITY_SCENE := preload("res://src/Entities/entity.tscn")

var visual: Node2D
var sprite: Sprite2D

enum AIType {NONE, HOSTILE}
enum EntityType {CORPSE, ITEM, ACTOR}

const entity_types = {
	"player": "res://assets/definitions/entities/actors/entity_definition_player.tres",
	"orc": "res://assets/definitions/entities/actors/entity_definition_orc.tres",
	"troll": "res://assets/definitions/entities/actors/entity_definition_troll.tres",
	"health_potion": "res://assets/definitions/entities/items/health_potion_definition.tres",
	"lightning_scroll": "res://assets/definitions/entities/items/lightning_scroll_definition.tres",
	"confusion_scroll": "res://assets/definitions/entities/items/confusion_scroll_definition.tres",
	"fireball_scroll": "res://assets/definitions/entities/items/fireball_scroll_definition.tres",
	"dagger": "res://assets/definitions/entities/items/dagger_definition.tres",
	"sword": "res://assets/definitions/entities/items/sword_definition.tres",
	"chainmail": "res://assets/definitions/entities/items/chainmail_definition.tres",
	"leather_armor": "res://assets/definitions/entities/items/leather_armor_definition.tres",
}

var key: String

var type: EntityType:
	set(value):
		type = value
		z_index = type

var _definition: EntityDefinition
var entity_name: String
var blocks_movement: bool
var map_data: MapData
var grid_position: Vector2i:
	set(value):
		grid_position = value
		position = Grid.grid_to_world(grid_position)
var fighter_component: FighterComponent
var ai_controller: AIController
var consumable_component: ConsumableComponent
var attachable_component: AttachableComponent
var inventory_component: InventoryComponent
var attachment_component: AttachmentComponent


func get_save_data() -> Dictionary:
	var save_data: Dictionary = {
		"x": grid_position.x,
		"y": grid_position.y,
		"key": key,
	}
	if fighter_component:
		save_data["fighter_component"] = fighter_component.get_save_data()
	if inventory_component:
		save_data["inventory_component"] = inventory_component.get_save_data()
	if attachment_component:
		save_data["attachment_component"] = attachment_component.get_save_data()
	if ai_controller != null:
		save_data["ai_controller"] = ai_controller.get_save_data()
	return save_data

static func validate_save_data(
	data: Variant,
	depth: int = 0
) -> String:
	if depth > 16:
		return "Saved entities are nested too deeply."

	if not data is Dictionary:
		return "Entity data must be a dictionary."

	var saved_key: Variant = data.get("key")

	if not saved_key is String:
		return "Entity key must be a string."

	if not entity_types.has(saved_key):
		return "Unknown entity key: %s." % saved_key

	for coordinate in ["x", "y"]:
		if not SaveChecks.is_integer(data.get(coordinate)):
			return "Entity %s must be a whole number." % coordinate

	var definition := load(entity_types[saved_key]) as EntityDefinition

	if definition == null:
		return "Could not load definition for %s." % saved_key

	var expected_components := {
		"fighter_component": definition.fighter_definition != null,
		"inventory_component": definition.type == EntityType.ACTOR,
		"attachment_component": definition.type == EntityType.ACTOR,
		"ai_controller": definition.ai_type != AIType.NONE,
	}

	# Check presence before inspecting component contents.
	for component_name in expected_components:
		var expected: bool = expected_components[component_name]

		if expected and not data.has(component_name):
			return "%s is missing %s." % [saved_key, component_name]

		if not expected and data.has(component_name):
			return "%s should not contain %s." % [
				saved_key,
				component_name,
			]

	var error: String

	if expected_components["fighter_component"]:
		error = FighterComponent.validate_save_data(
			data["fighter_component"]
		)
		if not error.is_empty():
			return "fighter_component: %s" % error

	if expected_components["inventory_component"]:
		error = InventoryComponent.validate_save_data(
			data["inventory_component"],
			depth
		)
		if not error.is_empty():
			return "inventory_component: %s" % error

	if expected_components["attachment_component"]:
		error = AttachmentComponent.validate_save_data(
			data["attachment_component"],
			depth
		)
		if not error.is_empty():
			return "attachment_component: %s" % error

	if expected_components["ai_controller"]:
		error = AIController.validate_save_data(data["ai_controller"])
		if not error.is_empty():
			return "ai_controller: %s" % error

		var stack: Array = data["ai_controller"]["stack"]
		var dead := false

		if expected_components["fighter_component"]:
			dead = data["fighter_component"]["hp"] == 0

		if dead and not stack.is_empty():
			return "A dead entity must have an empty AI stack."

		if not dead and stack.is_empty():
			return "An entity with active AI must have a base behavior."

	return ""

# Requires validated data and a fresh, unconfigured Entity.
# Call after Entity.create(..., "") and before adding it to the tree.
func restore_save_data(data: Dictionary) -> void:
	assert(_definition == null, "Restore requires an unconfigured Entity.")
	assert(not is_inside_tree(), "Restore before entering the SceneTree.")

	grid_position = Vector2i(int(data["x"]), int(data["y"]))
	set_entity_type(data["key"])

	if fighter_component != null:
		fighter_component.restore_save_data(data["fighter_component"])

	if inventory_component != null:
		inventory_component.restore_save_data(data["inventory_component"])

	if attachment_component != null:
		attachment_component.restore_save_data(data["attachment_component"])
	
	if ai_controller != null:
		ai_controller.restore_save_data(data["ai_controller"])
	
	if fighter_component != null and fighter_component.hp == 0:
		apply_dead_state()
		return


static func create(map_data: MapData, start_position: Vector2i, key: String = "") -> Entity:
	var entity := ENTITY_SCENE.instantiate() as Entity
	entity.setup(map_data, start_position, key)

	return entity

func setup(_map_data: MapData, start_position: Vector2i, key: String = "") -> void:
	visual = $Visual
	sprite = $Visual/Sprite
	grid_position = start_position
	map_data = _map_data
	if key != "":
		set_entity_type(key)
		_initialize_default_ai()

func set_entity_type(key: String) -> void:
	self.key = key
	var entity_definition: EntityDefinition = load(entity_types[key])
	_definition = entity_definition
	type = _definition.type
	blocks_movement = _definition.is_blocking_movement
	entity_name = _definition.name
	sprite.texture = entity_definition.texture
	sprite.modulate = entity_definition.color
	
	if entity_definition.ai_type != AIType.NONE:
		ai_controller = AIController.new(self)
		add_child(ai_controller)
	
	if entity_definition.fighter_definition:
		fighter_component = FighterComponent.new(entity_definition.fighter_definition)
		add_child(fighter_component)
		
	var item_definition: ItemComponentDefinition = entity_definition.item_definition
	if item_definition:
		if item_definition is ConsumableComponentDefinition:
			_handle_consumable(item_definition)
		else:
			attachable_component = AttachableComponent.new(item_definition)
			add_child(attachable_component)
	
	if entity_definition.type == EntityType.ACTOR:
		inventory_component = InventoryComponent.new(
			entity_definition.inventory_capacity
		)
		inventory_component.entity = self
		add_child(inventory_component)

		attachment_component = AttachmentComponent.new()
		attachment_component.entity = self
		add_child(attachment_component)

func _initialize_default_ai() -> void:
	match _definition.ai_type:
		AIType.HOSTILE:
			ai_controller.push(HostileEnemyAIComponent.new())

func move_into_storage(storage: Node) -> void:
	assert(get_parent() == null)

	hide()
	map_data = null
	grid_position = Vector2i(-1, -1)

	visual.position = Vector2.ZERO
	sprite.position = Vector2.ZERO

	storage.add_child(self)

func _handle_consumable(consumable_definition: ConsumableComponentDefinition) -> void:
	if consumable_definition is HealingConsumableComponentDefinition:
		consumable_component = HealingConsumableComponent.new(consumable_definition)
	elif consumable_definition is LightningDamageConsumableComponentDefinition:
		consumable_component = LightningDamageConsumableComponent.new(consumable_definition)
	elif consumable_definition is ConfusionConsumableComponentDefinition:
		consumable_component = ConfusionConsumableComponent.new(consumable_definition)
	elif consumable_definition is FireballDamageConsumableComponentDefinition:
		consumable_component = FireballDamageConsumableComponent.new(consumable_definition)
		
	if consumable_component:
		add_child(consumable_component)
	consumable_component.entity = self

func is_alive() -> bool:
	return (
		type == EntityType.ACTOR
		and fighter_component != null
		and fighter_component.hp > 0
	)

func is_blocking_movement() -> bool:
	return blocks_movement

func get_entity_name() -> String:
	return entity_name

func move(move_offset: Vector2i) -> void:
	map_data.unregister_blocking_entity(self)
	var old_position := position
	grid_position += move_offset
	map_data.register_blocking_entity(self)
	visual.position = old_position - position
	var tween := create_tween()
	tween.tween_property(
		visual,
		"position",
		Vector2.ZERO,
		0.14
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var jump_tween := create_tween()

	jump_tween.tween_property(
		sprite,
		"position:y",
		-6.0,
		0.07
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	jump_tween.tween_property(
		sprite,
		"position:y",
		0.0,
		0.07
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	


func distance(other_position: Vector2i) -> int:
	var relative: Vector2i = other_position - grid_position
	return maxi(abs(relative.x), abs(relative.y))

func apply_dead_state() -> void:
	assert(fighter_component != null)

	type = EntityType.CORPSE
	blocks_movement = false
	entity_name = "Remains of %s" % _definition.name

	sprite.texture = fighter_component.death_texture
	sprite.modulate = fighter_component.death_color

	if ai_controller != null:
		ai_controller.clear()
