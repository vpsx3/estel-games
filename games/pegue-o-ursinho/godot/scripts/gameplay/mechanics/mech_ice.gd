class_name MechIce
extends MechBase
## Piso escorregadio (bioma 2). Porta moveBearIce. Velocidade em unidade LEGADA (px/frame) em
## bear.vel; o deslocamento usa Units. Global: so configuracao (accel, friction, maxSpd, bounce).
## accel/friction do JS sao POR FRAME; aqui escalados por f = dt*60 (identico a 60 fps).


func move_bear(r: GameRun, dt: float, input: Vector2) -> bool:
	var bear: BearModel = r.bear
	var mag: float = input.length()
	bear.moving = mag > 0.01
	if mag > 0.01:
		bear.facing = BearModel.dir_from_vec(input.x, input.y, bear.facing)
	if bear.landing_target != null:
		return true
	var n: Vector2 = input
	if mag > 1.0:
		n = input / mag
	var f: float = dt * Units.LEGACY_FPS
	bear.vel = (bear.vel + n * cfg_f("accel") * f) * pow(cfg_f("friction"), f)
	var sp: float = bear.vel.length()
	var mx: float = cfg_f("maxSpd")
	if sp > mx:
		bear.vel = bear.vel / sp * mx
	var step: Vector2 = bear.vel * f * Units.TILE_SCALE
	var nx: float = bear.pos.x + step.x
	var ny: float = bear.pos.y + step.y
	if r.is_phasing():
		if nx > bear.size and nx < Units.WORLD_W - bear.size:
			bear.pos.x = nx
		if ny > bear.size and ny < Units.WORLD_H - bear.size:
			bear.pos.y = ny
	else:
		if GridCollision.can_move(r.level, nx, bear.pos.y, bear.size) and not r.mech_blocks_bear(nx, bear.pos.y):
			bear.pos.x = nx
		else:
			bear.vel.x *= -cfg_f("bounce")
		if GridCollision.can_move(r.level, bear.pos.x, ny, bear.size) and not r.mech_blocks_bear(bear.pos.x, ny):
			bear.pos.y = ny
		else:
			bear.vel.y *= -cfg_f("bounce")
	bear.clamp_to_world()
	return true
