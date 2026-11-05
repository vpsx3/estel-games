class_name PouJoystick
extends RefCounted
## Logica do joystick virtual (porta joyStart/joyMove/joyEnd). Sem desenho/entrada de cena.
## Raio JOY_RADIUS e em px de UI (nao e unidade de mundo; sem conversao por Units).
## Zona morta 0.18 (JS). O vetor NAO e limitado a 1 (como no JS); BearModel.move normaliza.

var center: Vector2 = Vector2.ZERO
var vec: Vector2 = Vector2.ZERO
var active: bool = false
var last: Vector2 = Vector2.ZERO


static func radius() -> float:
	return GameplayLits.c("JOY_RADIUS")


func start(center_pos: Vector2, pos: Vector2) -> void:
	center = center_pos
	active = true
	move(pos)


func move(pos: Vector2) -> void:
	last = pos
	var d: Vector2 = pos - center
	var n: Vector2 = d / radius()
	if n.length() < GameplayLits.JOY_DEADZONE:
		vec = Vector2.ZERO
	else:
		vec = n


func end() -> void:
	vec = Vector2.ZERO
	active = false


## Deslocamento do knob (limitado ao raio) para desenho.
func knob_offset() -> Vector2:
	var d: Vector2 = last - center
	return d.limit_length(radius())
