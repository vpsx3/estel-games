class_name ResultScreen
extends UiScreen
## screenResult (endGame): tempo, fantasmas + build, mel, bioma alcancado e mensagem de ranking.
## show_result() preenche; set_saving()/set_rank() atualizam a mensagem quando o POST /api/scores volta.

signal play_again_pressed
signal menu_pressed
signal ranking_pressed

@onready var time_label: Label = %TimeLabel
@onready var ghosts_label: Label = %GhostsLabel
@onready var build_icons: HBoxContainer = %BuildIcons
@onready var honey_label: Label = %HoneyLabel
@onready var biome_label: Label = %BiomeLabel
@onready var rank_msg_label: Label = %RankMsgLabel
@onready var play_again_button: Button = %PlayAgainButton
@onready var menu_button: Button = %MenuButton
@onready var ranking_button: Button = %RankingButton

var _stats: Dictionary = {}
var _build: Array = []
var _rank_state: String = "saving"   # saving | rank | miss
var _rank: int = 0


func _ready() -> void:
	super()
	play_again_button.pressed.connect(func() -> void: play_again_pressed.emit())
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	ranking_button.pressed.connect(func() -> void: ranking_pressed.emit())
	UiIcons.apply(%GhostIcon as TextureRect, "ghost", UiIcons.color_for("ghost"), "F")


## stats = GameRun.last_stats; build_ids = BuffSystem.build_ids (buildIcons).
func show_result(stats: Dictionary, build_ids: Array) -> void:
	_stats = stats
	_build = build_ids.duplicate()
	set_saving()
	_rebuild_build()


func set_saving() -> void:
	_rank_state = "saving"
	refresh()


## Resposta do saveScore: rank 1 / top 10 / fora do top.
func set_rank(rank: Variant) -> void:
	if rank != null and int(rank) > 0 and int(rank) <= 10:
		_rank_state = "rank"
		_rank = int(rank)
	else:
		_rank_state = "miss"
	refresh()


func refresh() -> void:
	if _stats.is_empty():
		return
	var n: int = int(_stats.get("ghosts", 0))
	time_label.text = UiText.format_time(float(_stats.get("seconds", 0)))
	ghosts_label.text = "%d %s%s" % [n, I18n.t("ghost_word"), "s" if n > 1 else ""]
	honey_label.text = "%s: +%d" % [I18n.t("result_honey"), int(_stats.get("honey", 0))]
	var idx: int = int(_stats.get("biome_index", 0))
	var cycle: int = int(_stats.get("cycle", 0))
	var cycle_str: String = (" · %s %d" % [I18n.t("cycle_label"), cycle + 1]) if cycle > 0 else ""
	biome_label.text = "%s%s%s" % [I18n.t("result_reached"), I18n.biome_name(idx), cycle_str]
	match _rank_state:
		"saving":
			rank_msg_label.text = I18n.t("result_saving")
		"rank":
			rank_msg_label.text = I18n.t("result_rank1") if _rank == 1 else I18n.tf("result_topN", {"n": _rank})
		_:
			rank_msg_label.text = I18n.t("result_miss")


func _rebuild_build() -> void:
	for c: Node in build_icons.get_children():
		build_icons.remove_child(c)
		c.queue_free()
	for id: Variant in _build:
		build_icons.add_child(UiIcons.make_buff(str(id), 32))
