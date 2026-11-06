class_name BuffCard
extends Button
## Carta de buff (buff-card do HTML). Botao com toggle_mode: pressed = selecionada.
## Filhos (todos com mouse ignorado): SelNum, Icon, NameLabel, DescLabel, RarityLabel, TypeLabel.
## Variacao de tema do raridade: RarityComum / RarityIncomum / RarityRaro (Label).

var buff_id: String = ""

@onready var sel_num: Label = %SelNum
@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var desc_label: Label = %DescLabel
@onready var rarity_label: Label = %RarityLabel
@onready var type_label: Label = %TypeLabel


func _ready() -> void:
	Events.language_changed.connect(func(_l: String) -> void: _texts())


func setup(buff: Dictionary, show_number: bool) -> void:
	buff_id = str(buff["id"])
	set_meta("buff", buff)
	sel_num.visible = show_number
	sel_num.text = ""
	var rar: String = str(buff["rar"])
	theme_type_variation = StringName("BuffCard" + rar.capitalize())   # moldura por raridade (cozy_theme)
	rarity_label.theme_type_variation = StringName("Rarity" + rar.capitalize())
	UiIcons.apply(icon_rect, buff_id, UiIcons.rarity_color(rar), I18n.buff_name(buff_id))
	_texts()


func set_pick_index(i: int) -> void:
	sel_num.text = str(i + 1) if i >= 0 else ""
	set_pressed_no_signal(i >= 0)


func _texts() -> void:
	if buff_id == "":
		return
	var buff: Dictionary = get_meta("buff") as Dictionary
	name_label.text = I18n.buff_name(buff_id)
	desc_label.text = I18n.buff_desc(buff_id)
	rarity_label.text = I18n.rarity_label(str(buff["rar"]))
	type_label.text = I18n.t("type_fixed") if str(buff["type"]) == "fixed" else I18n.t("type_map")
