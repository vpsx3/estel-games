class_name BuffSelectScreen
extends UiScreen
## buffScreen: selecao pre-run (5 opcoes, escolhe 3). Usa BuffSystem.toggle_pick / can_start.
## O botao Iniciar so habilita com 3 picks e emite start_pressed (o fluxo chama Game.begin()).

signal start_pressed

const CARD: PackedScene = preload("res://scenes/ui/buff_card.tscn")

@onready var cards: VBoxContainer = %Cards
@onready var start_button: Button = %StartButton

var buffs: BuffSystem
var card_nodes: Array[BuffCard] = []


func _ready() -> void:
	super()
	start_button.pressed.connect(func() -> void:
		if buffs != null and buffs.can_start():
			start_pressed.emit())


## openSelection(): monta as cartas a partir de buffs.selection_options.
func open(p_buffs: BuffSystem) -> void:
	buffs = p_buffs
	for c: Node in cards.get_children():
		cards.remove_child(c)
		c.queue_free()
	card_nodes.clear()
	for b: Dictionary in buffs.selection_options:
		var card: BuffCard = CARD.instantiate() as BuffCard
		cards.add_child(card)
		card.setup(b, true)
		card.pressed.connect(_on_card.bind(card))
		card_nodes.append(card)
	_update()


func _on_card(card: BuffCard) -> void:
	buffs.toggle_pick(card.buff_id)   # togglePick: no maximo 3
	_update()


## Numeracao das cartas + updateStartBtn().
func _update() -> void:
	for card: BuffCard in card_nodes:
		card.set_pick_index(buffs.selection_picks.find(card.buff_id))
	refresh()


func refresh() -> void:
	if buffs == null:
		start_button.text = I18n.tf("btn_start_run", {"n": 0})
		start_button.disabled = true
		return
	start_button.text = I18n.tf("btn_start_run", {"n": buffs.selection_picks.size()})
	start_button.disabled = not buffs.can_start()
