class_name UpgradesScreen
extends UiScreen
## screenUpgrades: loja de atributos persistentes (ATTR_ORDER). Compra via Shop (debita o mel do save).

signal back_pressed
signal purchased(id: String)

const CARD: PackedScene = preload("res://scenes/ui/upgrade_card.tscn")

@onready var balance_label: Label = %BalanceLabel
@onready var list: VBoxContainer = %List
@onready var back_button: Button = %BackButton


func _ready() -> void:
	super()
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	UiIcons.apply(%BalanceIcon as TextureRect, "honey", UiIcons.color_for("honey"), "M")


## renderUpgrades()
func refresh() -> void:
	var shop: Shop = Shop.new()
	balance_label.text = str(shop.honey())
	for c: Node in list.get_children():
		list.remove_child(c)
		c.queue_free()
	for id: String in Shop.order():
		var card: UpgradeCard = CARD.instantiate() as UpgradeCard
		list.add_child(card)
		card.setup(id, shop)
		card.buy_pressed.connect(_on_buy)


func _on_buy(id: String) -> void:
	if Shop.new().buy(id):
		purchased.emit(id)
		refresh()
