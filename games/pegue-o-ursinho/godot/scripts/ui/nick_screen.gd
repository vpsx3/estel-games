class_name NickScreen
extends UiScreen
## screenNick: apelido + Jogar + Ranking. btnPlay: trim; vazio => foco + marca de erro.
## O limite de 16 caracteres e o max_length do LineEdit NickInput (maxlength=16 do HTML).

signal submitted(nick: String)
signal ranking_requested

@onready var nick_input: LineEdit = %NickInput
@onready var play_button: Button = %PlayButton
@onready var ranking_button: Button = %RankingButton


func _ready() -> void:
	super()
	play_button.pressed.connect(submit)
	nick_input.text_submitted.connect(func(_t: String) -> void: submit())
	ranking_button.pressed.connect(func() -> void: ranking_requested.emit())
	UiIcons.apply(%Icon as TextureRect, "bear", UiIcons.color_for("bear"), "U")


## nickInput.value.trim()
static func clean_nick(raw: String) -> String:
	return raw.strip_edges()


func submit() -> bool:
	var v: String = clean_nick(nick_input.text)
	if v.is_empty():
		nick_input.theme_type_variation = &"InvalidLineEdit"   # borda vermelha do HTML
		nick_input.grab_focus()
		return false
	nick_input.theme_type_variation = &""
	submitted.emit(v)
	return true
