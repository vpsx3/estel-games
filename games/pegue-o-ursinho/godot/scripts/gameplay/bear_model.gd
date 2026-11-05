class_name BearModel
extends RefCounted
## Estado e movimento do urso. Porta o objeto `bear` do initGame + moveBear + dirFromVec.
## Velocidade em UNIDADE LEGADA (px/frame @60fps); convertida por Units no uso.
## size em px do Godot (Units.px(14)).

var pos: Vector2 = Vector2.ZERO
var size: float = Units.px(GameplayLits.BEAR_SIZE)
var base_speed: float = 0.0     # 3.3 * INITIAL_PACE (legado)
var speed: float = 0.0          # base_speed * (1 + speed_base attr)
var frozen: float = 0.0
var invuln: float = 0.0
var landing_target: Variant = null   # null | Vector2
var landing_glide: bool = false
var facing: String = "south"
var moving: bool = false
var poisoned: bool = false
var poison_left: float = 0.0    # s (JS usa Date.now(); aqui relogio de jogo)
var vel: Vector2 = Vector2.ZERO # inercia (mecanica de gelo, E4b)
var mush_cd: float = 0.0        # cooldown de cogumelo (E4b)


func _init() -> void:
	base_speed = GameplayLits.BEAR_BASE_SPEED * GameplayLits.c("INITIAL_PACE")
	speed = base_speed


static func dir_from_vec(dx: float, dy: float, current: String = "south") -> String:
	if absf(dx) < 0.01 and absf(dy) < 0.01:
		return current if current != "" else "south"
	if absf(dx) > absf(dy):
		return "east" if dx > 0.0 else "west"
	return "south" if dy > 0.0 else "north"


## moveBear(dt). `run` fornece: level, bear_speed_mult(), mech_speed_mult(), mech_blocks_bear(x,y),
## mech_apply_drift(dt), is_phasing(). `input` = vetor (teclado ou joystick), pode ter |v| > 1.
func move(run: GameRun, dt: float, input: Vector2) -> void:
	if frozen > 0.0:
		return
	if run.mech_move_bear(dt, input):   # gancho: gelo (inercia) assume o movimento
		return
	var mag: float = input.length()
	moving = mag > 0.01
	if mag > 0.01:
		facing = dir_from_vec(input.x, input.y, facing)
	if landing_target != null:
		return
	if mag < 0.01:
		return
	var n: Vector2 = input
	if mag > 1.0:
		n = input / mag
	var mult: float = run.bear_speed_mult() * run.mech_speed_mult() * (GameplayLits.c("POISON_DEBUFF") if poisoned else 1.0)
	var spd: float = Units.speed_px_frame_to_px_s(speed * mult) * dt
	var nx: float = pos.x + n.x * spd
	var ny: float = pos.y + n.y * spd
	var level: Object = run.level
	if run.is_phasing():
		if nx > size and nx < Units.WORLD_W - size:
			pos.x = nx
		if ny > size and ny < Units.WORLD_H - size:
			pos.y = ny
	else:
		if GridCollision.can_move(level, nx, pos.y, size) and not run.mech_blocks_bear(nx, pos.y):
			pos.x = nx
		else:
			var sx: float = pos.x + n.x * spd * GameplayLits.WALL_SLIDE
			if GridCollision.can_move(level, sx, pos.y, size) and not run.mech_blocks_bear(sx, pos.y):
				pos.x = sx
		if GridCollision.can_move(level, pos.x, ny, size) and not run.mech_blocks_bear(pos.x, ny):
			pos.y = ny
		else:
			var sy: float = pos.y + n.y * spd * GameplayLits.WALL_SLIDE
			if GridCollision.can_move(level, pos.x, sy, size) and not run.mech_blocks_bear(pos.x, sy):
				pos.y = sy
	clamp_to_world()
	run.mech_apply_drift(dt)


## landingTarget = {x,y,glide:true}: desliza ate a celula mesmo sobre parede (mecanicas de bioma).
func glide_to(target: Vector2) -> void:
	landing_target = target
	landing_glide = true


func clamp_to_world() -> void:
	pos.x = maxf(size, minf(Units.WORLD_W - size, pos.x))
	pos.y = maxf(size, minf(Units.WORLD_H - size, pos.y))
