class_name MenuScreen
extends UiScreen
## screenMenu: mel acumulado + Jogar / Upgrades / Skins (desabilitado, em breve) / Ranking.

signal play_pressed
signal upgrades_pressed
signal ranking_pressed

@onready var honey_label: Label = %HoneyLabel
@onready var play_button: Button = %PlayButton
@onready var upgrades_button: Button = %UpgradesButton
@onready var skins_button: Button = %SkinsButton
@onready var ranking_button: Button = %RankingButton


func _ready() -> void:
	super()
	play_button.pressed.connect(func() -> void: play_pressed.emit())
	upgrades_button.pressed.connect(func() -> void: upgrades_pressed.emit())
	ranking_button.pressed.connect(func() -> void: ranking_pressed.emit())
	skins_button.disabled = true
	UiIcons.apply(%HoneyIcon as TextureRect, "honey", UiIcons.color_for("honey"), "M")


## refreshMenu()
func refresh() -> void:
	honey_label.text = str(Save.honey())
