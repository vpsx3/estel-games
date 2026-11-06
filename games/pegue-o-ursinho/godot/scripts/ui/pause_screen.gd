class_name PauseScreen
extends UiScreen
## Pausa (Esc / botao). O HTML nao tem pausa: e extensao do port. Continuar ou sair para o menu
## (a run abandonada nao envia score).

signal resume_pressed
signal menu_pressed

@onready var resume_button: Button = %ResumeButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	super()
	resume_button.pressed.connect(func() -> void: resume_pressed.emit())
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())
