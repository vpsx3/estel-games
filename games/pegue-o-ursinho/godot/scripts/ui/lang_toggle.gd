class_name LangToggle
extends HBoxContainer
## Botoes EN | PT (lang-toggle-game do HTML). Chama I18n.set_lang; sincroniza com language_changed.

@onready var en_button: Button = %EN
@onready var pt_button: Button = %PT


func _ready() -> void:
	en_button.pressed.connect(func() -> void: I18n.set_lang("en"))
	pt_button.pressed.connect(func() -> void: I18n.set_lang("pt"))
	Events.language_changed.connect(func(_l: String) -> void: _sync())
	_sync()


func _sync() -> void:
	en_button.set_pressed_no_signal(I18n.lang == "en")
	pt_button.set_pressed_no_signal(I18n.lang == "pt")
