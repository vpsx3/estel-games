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
	# Celular no navegador: o Godot web nao abre o teclado virtual para LineEdit.
	# Um toque no campo abre a caixa de texto nativa (window.prompt), que traz o teclado do aparelho.
	if _use_native_prompt():
		# sem foco (o LineEdit nao edita nada aqui), mas com aparencia normal (editable=false o deixaria cinza)
		nick_input.focus_mode = Control.FOCUS_NONE
		nick_input.virtual_keyboard_enabled = false
		nick_input.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		nick_input.gui_input.connect(_on_nick_gui_input)


static func _use_native_prompt() -> bool:
	return OS.has_feature("web") and Device.is_touch()


func _on_nick_gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch or ev is InputEventMouseButton or ev is InputEventScreenDrag:
		accept_event()   # o LineEdit nao recebe o press (evita grab_focus num controle sem foco)
	var tapped: bool = (ev is InputEventScreenTouch and not (ev as InputEventScreenTouch).pressed) \
		or (ev is InputEventMouseButton and not (ev as InputEventMouseButton).pressed \
			and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if tapped:
		accept_event()
		ask_nick_native()


var _last_prompt_ms: int = -100000

## Abre a caixa nativa e copia o resultado (limitado a max_length) para o NickInput.
## Um toque chega como toque E como clique emulado: ignora repeticoes em menos de 700 ms.
func ask_nick_native() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_prompt_ms < 700:
		return
	_last_prompt_ms = now
	var msg: String = nick_input.placeholder_text if nick_input.placeholder_text != "" else "Apelido"
	var v: Variant = WebBridge.prompt(msg, nick_input.text)
	# o prompt bloqueia o jogo enquanto o jogador digita: o clique emulado chega DEPOIS
	_last_prompt_ms = Time.get_ticks_msec()
	if v == null:
		return
	var s: String = clean_nick(str(v))
	if nick_input.max_length > 0:
		s = s.left(nick_input.max_length)
	nick_input.text = s
	if not s.is_empty():
		nick_input.theme_type_variation = &""


## nickInput.value.trim()
static func clean_nick(raw: String) -> String:
	return raw.strip_edges()


func submit() -> bool:
	var v: String = clean_nick(nick_input.text)
	if v.is_empty():
		nick_input.theme_type_variation = &"InvalidLineEdit"   # borda vermelha do HTML
		if _use_native_prompt():
			ask_nick_native()   # no celular, ja abre o teclado em vez de so marcar o erro
			v = clean_nick(nick_input.text)
			if v.is_empty():
				return false
		else:
			nick_input.grab_focus()
			return false
	nick_input.theme_type_variation = &""
	submitted.emit(v)
	return true
