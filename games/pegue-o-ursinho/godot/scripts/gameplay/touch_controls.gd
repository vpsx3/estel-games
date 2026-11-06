class_name TouchControls
extends Control
## Controles de toque (logica + desenho placeholder): joystick virtual fixo no canto inferior
## esquerdo e botao de pulo no direito. Visivel so em dispositivos de toque (Device.is_touch())
## ou com force_visible. Mouse tambem aciona o joystick (como mouseJoy do JS). Arte final: E4c.

signal jump_pressed

@export var force_visible: bool = false

var joystick: PouJoystick = PouJoystick.new()
var jump_cd_text: String = ""          # preenchido pela cena de jogo (ex.: "3s")
var _joy_finger: int = -2              # -2 nenhum, -1 mouse, >=0 indice do toque
var _joy_center: Vector2 = Vector2.ZERO
var _jump_center: Vector2 = Vector2.ZERO
const JUMP_R: float = 54.0            # botao 108 px = textura jump_normal 1:1 (area de toque >= 48)
const TEX_JOY_BASE: Texture2D = preload("res://assets/ui/panels/joystick_base.png")
const TEX_JOY_KNOB: Texture2D = preload("res://assets/ui/panels/joystick_knob.png")
const TEX_JUMP: Texture2D = preload("res://assets/ui/panels/jump_normal.png")
const TEX_JUMP_CD: Texture2D = preload("res://assets/ui/panels/jump_cooldown.png")
var jump_cd_ratio: float = 0.0         # recarga restante 0..1 (jump.cd / jump.cd_max), preenchido pela cena de jogo


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = force_visible or Device.is_touch()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	_joy_center = Vector2(PouJoystick.radius() + 48.0, vp.y - PouJoystick.radius() - 56.0)
	_jump_center = Vector2(vp.x - JUMP_R - 48.0, vp.y - JUMP_R - 64.0)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			if t.position.distance_to(_jump_center) <= JUMP_R * 1.4:
				jump_pressed.emit()
			elif _joy_finger == -2 and t.position.distance_to(_joy_center) <= PouJoystick.radius() * 2.0:
				_joy_finger = t.index
				joystick.start(_joy_center, t.position)
		elif t.index == _joy_finger:
			_joy_finger = -2
			joystick.end()
		queue_redraw()
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if d.index == _joy_finger:
			joystick.move(d.position)
			queue_redraw()
	elif event is InputEventMouseButton:
		var m: InputEventMouseButton = event
		if m.button_index == MOUSE_BUTTON_LEFT:
			if m.pressed:
				if m.position.distance_to(_jump_center) <= JUMP_R * 1.4:
					jump_pressed.emit()
				elif _joy_finger == -2 and m.position.distance_to(_joy_center) <= PouJoystick.radius() * 2.0:
					_joy_finger = -1
					joystick.start(_joy_center, m.position)
			elif _joy_finger == -1:
				_joy_finger = -2
				joystick.end()
			queue_redraw()
	elif event is InputEventMouseMotion and _joy_finger == -1:
		joystick.move((event as InputEventMouseMotion).position)
		queue_redraw()


## Recebe o estado do pulo (cena de jogo chama todo frame).
func set_jump_cooldown(cd: float, cd_max: float) -> void:
	var ratio: float = clampf(cd / cd_max, 0.0, 1.0) if cd_max > 0.0 else 0.0
	if absf(ratio - jump_cd_ratio) > 0.002 or (ratio == 0.0) != (jump_cd_ratio == 0.0):
		jump_cd_ratio = ratio
		queue_redraw()


func _draw() -> void:
	# Arte em escala 0.5 (pixel-perfect); o raio logico (JOY_RADIUS) nao muda, so o desenho e maior.
	var br: Vector2 = TEX_JOY_BASE.get_size() * 0.5 * 0.5
	draw_texture_rect(TEX_JOY_BASE, Rect2(_joy_center - br, br * 2.0), false, Color(1, 1, 1, 0.85))
	var kr: float = TEX_JOY_KNOB.get_size().x * 0.25
	draw_texture_rect(TEX_JOY_KNOB, Rect2(_joy_center + joystick.knob_offset() - Vector2(kr, kr), Vector2(kr, kr) * 2.0), false)
	var jr: Vector2 = Vector2(JUMP_R, JUMP_R)
	var tex: Texture2D = TEX_JUMP_CD if jump_cd_ratio > 0.0 else TEX_JUMP
	draw_texture_rect(tex, Rect2(_jump_center - jr, jr * 2.0), false)
	if jump_cd_ratio > 0.0:   # arco de recarga: some no sentido horario ate liberar
		draw_arc(_jump_center, JUMP_R + 5.0, -PI / 2.0, -PI / 2.0 + TAU * jump_cd_ratio, 48, Color("#FFC83D"), 5.0, false)
