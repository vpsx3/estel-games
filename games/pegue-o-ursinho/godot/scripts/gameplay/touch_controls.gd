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
const JUMP_R: float = 40.0


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


func _draw() -> void:
	draw_circle(_joy_center, PouJoystick.radius(), Color(1, 1, 1, 0.12))
	draw_circle(_joy_center + joystick.knob_offset(), PouJoystick.radius() * 0.45, Color(1, 1, 1, 0.45))
	draw_circle(_jump_center, JUMP_R, Color(0.6, 1.0, 0.6, 0.3))
