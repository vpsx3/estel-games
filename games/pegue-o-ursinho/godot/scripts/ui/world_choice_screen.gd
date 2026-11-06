class_name WorldChoiceScreen
extends UiScreen
## worldChoice: escolha de +1 buff a cada troca de mundo (3 cartas) + Reroll (so com o atributo
## comprado; 1 por escolha). O fluxo liga picked -> BuffSystem.pick_world_buff e
## reroll_requested -> BuffSystem.world_reroll.

signal picked(id: String)
signal reroll_requested

const CARD: PackedScene = preload("res://scenes/ui/buff_card.tscn")

@onready var cards: VBoxContainer = %Cards
@onready var reroll_button: Button = %RerollButton


func _ready() -> void:
	super()
	reroll_button.pressed.connect(func() -> void: reroll_requested.emit())


## options = buffs.world_options; reroll_visible = reroll_enabled(); reroll_used = ja usou nesta escolha.
func show_options(options: Array, reroll_visible: bool, reroll_used: bool) -> void:
	for c: Node in cards.get_children():
		cards.remove_child(c)
		c.queue_free()
	for b: Dictionary in options:
		var card: BuffCard = CARD.instantiate() as BuffCard
		cards.add_child(card)
		card.setup(b, false)
		card.toggle_mode = false
		card.pressed.connect(func() -> void: picked.emit(card.buff_id))
	reroll_button.visible = reroll_visible
	reroll_button.disabled = reroll_used
