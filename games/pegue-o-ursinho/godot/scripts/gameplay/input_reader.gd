class_name InputReader
extends RefCounted
## Vetor de movimento: joystick virtual (se ativo) senao teclado (acoes do input map
## move_left/right/up/down = WASD + setas). Componentes em {-1,0,1} como keysDown do JS.


static func keyboard_vector() -> Vector2:
	var v: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		v.x -= 1.0
	if Input.is_action_pressed("move_right"):
		v.x += 1.0
	if Input.is_action_pressed("move_up"):
		v.y -= 1.0
	if Input.is_action_pressed("move_down"):
		v.y += 1.0
	return v


static func move_vector(joy: PouJoystick) -> Vector2:
	if joy != null and joy.active:
		return joy.vec
	return keyboard_vector()
