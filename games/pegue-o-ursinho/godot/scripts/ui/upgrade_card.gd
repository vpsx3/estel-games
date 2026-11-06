class_name UpgradeCard
extends PanelContainer
## Uma linha da loja (up-card). setup() le Shop; clique em BuyButton emite buy_pressed(id).

signal buy_pressed(id: String)

var attr_id: String = ""

@onready var icon: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var meta_label: Label = %MetaLabel
@onready var buy_button: Button = %BuyButton


func _ready() -> void:
	buy_button.pressed.connect(func() -> void: buy_pressed.emit(attr_id))


## renderUpgrades(): meta = "lv/max - efeito" (ou MAX); toggle = "Desbloquear".
func setup(id: String, shop: Shop) -> void:
	attr_id = id
	var d: Dictionary = Shop.def(id)
	var lv: int = shop.level(id)
	var cost: int = shop.next_cost(id)
	var maxed: bool = cost < 0
	name_label.text = I18n.attr_name(id)
	if bool(d.get("toggle", false)):
		meta_label.text = I18n.t("attr_unlock") + ((" - " + I18n.t("attr_max")) if maxed else "")
		buy_button.text = "%s\n%d" % [I18n.t("attr_unlock"), cost]
	else:
		var lvl: String = "%d/%d" % [lv, shop.max_level(id)]
		meta_label.text = "%s · %s" % [lvl, I18n.t("attr_max") if maxed else shop.effect_text(id)]
		buy_button.text = "%s\n%d" % [I18n.t("attr_buy"), cost]
	buy_button.visible = not maxed
	buy_button.disabled = not shop.can_buy(id)
	UiIcons.apply(icon, id, UiIcons.color_for(id), name_label.text)
	modulate.a = 0.7 if maxed else 1.0
