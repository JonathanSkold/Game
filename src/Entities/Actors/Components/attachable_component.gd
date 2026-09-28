class_name AttachableComponent
extends Component

enum AttachmentType { WEAPON, ARMOR }

var attachment_type: AttachmentType
var power_bonus: int
var defense_bonus: int


func _init(definition: AttachableComponentDefinition) -> void:
	attachment_type = definition.attachment_type
	power_bonus = definition.power_bonus
	defense_bonus = definition.defense_bonus
