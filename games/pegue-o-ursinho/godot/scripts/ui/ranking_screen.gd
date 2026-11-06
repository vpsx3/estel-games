class_name RankingScreen
extends UiScreen
## screenRanking: top do ranking global (GET /api/scores). open() mostra Carregando, busca e
## preenche; offline/vazio => "Nenhum recorde ainda".

signal back_pressed

const ROW: PackedScene = preload("res://scenes/ui/ranking_row.tscn")

@onready var status_label: Label = %StatusLabel
@onready var rows: VBoxContainer = %Rows
@onready var back_button: Button = %BackButton

var _req: int = 0
var _status_key: String = "rankingLoading"


func _ready() -> void:
	super()
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	UiIcons.apply(%GhostHeaderIcon as TextureRect, "ghost", UiIcons.color_for("ghost"), "F")


func refresh() -> void:
	status_label.text = I18n.t(_status_key)


## renderRanking(hlNick, hlSec). hl_sec < 0 => sem destaque.
func open(hl_nick: String = "", hl_sec: int = -1) -> void:
	_req += 1
	var mine: int = _req
	_clear()
	_set_status("rankingLoading")
	var scores: Array = await ApiClient.load_scores()
	if mine != _req or not is_inside_tree():
		return
	if scores.is_empty():
		_set_status("rankingEmpty")
		return
	status_label.visible = false
	for i in scores.size():
		var s: Dictionary = scores[i] as Dictionary
		var is_me: bool = hl_nick != "" and str(s.get("nick", "")) == hl_nick and int(s.get("seconds", -2)) == hl_sec
		var row: RankingRow = ROW.instantiate() as RankingRow
		rows.add_child(row)
		row.setup(i, s, is_me)


func _set_status(key: String) -> void:
	_status_key = key
	status_label.visible = true
	status_label.text = I18n.t(key)


func _clear() -> void:
	for c: Node in rows.get_children():
		rows.remove_child(c)
		c.queue_free()
