class_name PassiveChip
extends PanelContainer
## Chip de buff fixo (phud-chip): icone com cor da raridade + segundos ate o proximo disparo.

@onready var icon: TextureRect = %Icon
@onready var cooldown_label: Label = %CooldownLabel

var buff_id: String = ""


func set_buff(id: String, seconds_left: int) -> void:
	if buff_id != id:
		buff_id = id
		var def: Dictionary = BuffSystem.buff_def(id)
		UiIcons.apply(icon, id, UiIcons.rarity_color(str(def.get("rar", "comum"))), I18n.buff_name(id))
	cooldown_label.text = "%ds" % seconds_left
