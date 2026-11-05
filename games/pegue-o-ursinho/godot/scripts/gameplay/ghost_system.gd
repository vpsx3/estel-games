class_name GhostSystem
extends RefCounted
## Fantasmas: criacao, spawn ponderado, perseguicao, errante, veneno e separacao.
## Portes: weightedRandom, getDiffMult, makeGhost, spawnGhost, wanderMove, moveGhosts,
## resolveGhostCollisions, clampGhost, randomFreePosAway.
## Perseguicao do JS = linha reta ate o alvo (urso ou decoy), SEM pathfinding e sem colisao com paredes.

var run: GameRun
var ghosts: Array[GhostModel] = []


func _init(p_run: GameRun) -> void:
	run = p_run


func clear() -> void:
	ghosts.clear()


## weightedRandom(GHOST_TYPES): ordem do JSON (comum, rapido, pesado, errante, venenoso).
func weighted_random() -> String:
	var types: Dictionary = GameState.ghost_types
	var total: float = 0.0
	for k: String in types:
		total += float((types[k] as Dictionary)["weight"])
	var r: float = run.rng.randf() * total
	for k: String in types:
		r -= float((types[k] as Dictionary)["weight"])
		if r <= 0.0:
			return k
	return "comum"


## getDiffMult(): ghostSpeed efetivo do bioma * INITIAL_PACE * (1 + GHOST_PHASE_SCALING * fases).
func diff_mult() -> float:
	return run.biome_effective_speed() * GameplayLits.c("INITIAL_PACE") \
		* (1.0 + GameplayLits.c("GHOST_PHASE_SCALING") * run.cycle.phases_cleared)


func make_ghost(tipo: String, pos: Vector2) -> GhostModel:
	var tpl: Dictionary = GameState.ghost_types[tipo]
	var g: GhostModel = GhostModel.new()
	g.pos = pos
	g.speed = float(tpl["speed"]) * diff_mult()
	g.base_speed = float(tpl["speed"])
	g.base_class_speed = float(tpl["speed"])
	g.size = Units.px(float(tpl["size"]))
	g.tipo = tipo
	g.palette_index = ghosts.size() % (GameState.constants["GHOST_PALETTES"] as Array).size()
	g.mode_timer = GameplayLits.ERRANTE_MODE_BASE_MS + run.rng.randf() * GameplayLits.ERRANTE_MODE_RANGE_MS
	g.wander_dir = random_unit_dir()
	return g


func random_unit_dir() -> Vector2:
	var a: float = run.rng.randf() * TAU
	return Vector2(cos(a), sin(a))


## spawnGhost(minDistOverride): o 1o da run e sempre comum; distancia minima = minDist * TILE.
## min_dist_override_px < 0 => usa a minDist da classe.
func spawn_ghost(min_dist_override_px: float = -1.0) -> GhostModel:
	var tipo: String = "comum" if ghosts.is_empty() else weighted_random()
	var tpl: Dictionary = GameState.ghost_types[tipo]
	var md: float = min_dist_override_px if min_dist_override_px >= 0.0 else float(tpl["minDist"]) * Units.TILE
	var g: GhostModel = make_ghost(tipo, run.random_free_pos_away(run.bear.pos, md))
	ghosts.append(g)
	Events.ghost_spawned.emit(tipo)
	return g


func clamp_ghost(g: GhostModel) -> void:
	g.pos.x = maxf(g.size, minf(Units.WORLD_W - g.size, g.pos.x))
	g.pos.y = maxf(g.size, minf(Units.WORLD_H - g.size, g.pos.y))


func nearest_ghost() -> GhostModel:
	var best: GhostModel = null
	var bd: float = INF
	for g in ghosts:
		var d: float = g.pos.distance_to(run.bear.pos)
		if d < bd:
			bd = d
			best = g
	return best


func farthest_ghost() -> GhostModel:
	var best: GhostModel = null
	var bd: float = -1.0
	for g in ghosts:
		var d: float = g.pos.distance_to(run.bear.pos)
		if d > bd:
			bd = d
			best = g
	return best


## pushGhost(g): empurra TILE*1.6 para longe do urso.
func push_ghost(g: GhostModel) -> void:
	var delta: Vector2 = g.pos - run.bear.pos
	var d: float = delta.length()
	if d == 0.0:
		d = 1.0
	g.pos += delta / d * Units.TILE * GameplayLits.PUSH_CELLS
	clamp_ghost(g)


func wander_move(g: GhostModel, dt: float, gm: float) -> void:
	g.wander_timer -= dt * 1000.0
	var per: float = g.boost_mult if g.boost_timer > 0.0 else 1.0
	var step: float = Units.speed_px_frame_to_px_s(g.speed * gm * per) * dt
	var n: Vector2 = g.pos + g.wander_dir * step
	var blocked: bool = (not GridCollision.can_move(run.level, n.x, n.y, g.size)) \
		and GridCollision.can_move(run.level, g.pos.x, g.pos.y, g.size)
	if blocked or g.wander_timer <= 0.0:
		g.wander_dir = random_unit_dir()
		g.wander_timer = GameplayLits.WANDER_RETARGET_MS
	else:
		g.pos = n
		g.facing = BearModel.dir_from_vec(g.wander_dir.x, g.wander_dir.y, g.facing)


func move_ghosts(dt: float) -> void:
	if run.cycle.ghost_hide_timer > 0.0:
		return   # fantasmas ausentes logo apos a troca de bioma
	var gm: float = run.ghost_global_mult()
	var bear: BearModel = run.bear
	for g in ghosts:
		if g.frozen > 0.0 or g.trapped > 0.0:
			continue
		if run.invisible_timer > 0.0:
			continue
		if g.tipo == "errante":
			g.mode_timer -= dt * 1000.0
			if g.mode_timer <= 0.0:
				g.is_chasing = not g.is_chasing
				g.mode_timer = GameplayLits.ERRANTE_MODE_BASE_MS + run.rng.randf() * GameplayLits.ERRANTE_MODE_RANGE_MS
			if not g.is_chasing:
				wander_move(g, dt, gm)
				continue
		if g.tipo == "venenoso":
			if g.poison_timer > 0.0:
				g.poison_timer -= dt * 1000.0
				if g.poison_timer < 0.0:
					g.poison_timer = 0.0
			if g.poison_timer <= 0.0 and bear.pos.distance_to(g.pos) < Units.px(GameplayLits.c("POISON_RADIUS")):
				bear.poisoned = true
				bear.poison_left = GameplayLits.c("POISON_DURATION") / 1000.0   # nao acumula
				g.poison_timer = GameplayLits.c("POISON_COOLDOWN")
		var target: Vector2 = bear.pos
		if run.decoy != null and float((run.decoy as Dictionary)["life"]) > 0.0:
			target = (run.decoy as Dictionary)["pos"] as Vector2
		var per: float = g.boost_mult if g.boost_timer > 0.0 else 1.0
		var spd: float = Units.speed_px_frame_to_px_s(g.speed * gm * per) * dt
		var delta: Vector2 = target - g.pos
		var dist: float = delta.length()
		if dist == 0.0:
			dist = 1.0
		g.facing = BearModel.dir_from_vec(delta.x, delta.y, g.facing)
		g.pos += delta / dist * spd
	resolve_collisions()


## resolveGhostCollisions(): separacao par a par por soma dos raios; clamp no fim.
func resolve_collisions() -> void:
	for i in ghosts.size():
		for j in range(i + 1, ghosts.size()):
			var a: GhostModel = ghosts[i]
			var b: GhostModel = ghosts[j]
			var min_dist: float = a.size + b.size
			var delta: Vector2 = b.pos - a.pos
			var d: float = delta.length()
			if d < min_dist and d > 0.0:
				var o: float = (min_dist - d) / 2.0
				var u: Vector2 = delta / d
				if a.frozen <= 0.0 and a.trapped <= 0.0:
					a.pos -= u * o
				if b.frozen <= 0.0 and b.trapped <= 0.0:
					b.pos += u * o
			elif d == 0.0:
				b.pos.x += min_dist * 0.5
	for g in ghosts:
		clamp_ghost(g)
