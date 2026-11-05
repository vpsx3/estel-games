class_name GameRun
extends RefCounted
## Orquestrador da simulacao de uma run (sem nos de cena => testavel headless e deterministico
## com Rng(seed)). Porta initGame + gameLoop + moveBear/updateEffects/tryJump/executeBiomeTransition/
## endGame do index.html. Ordem do step() == ordem do gameLoop.
##
## `level` = Node2D com o contrato LevelRoot (is_wall, bear_spawn_cell, ghost_spawn_cell, config...)
## acessado por duck typing. `level_loader(biome_index) -> Node2D` troca o mapa na transicao.
##
## GANCHOS para E4b/E4c (todos opcionais):
##   mech_factory(run, biome_index) -> Object   mecanica do bioma; metodos opcionais
##       update(run, dt), move_bear(run, dt, input)->bool, blocks_bear(x,y)->bool,
##       speed_mult(run)->float, apply_drift(run, dt), ghost_alpha()->float
##   on_collectibles(dt)        updateCollectibles (buffs de mapa)
##   on_fixed_buffs(dt)         timers de buffs fixos
##   on_transition_reset()      limpa collectibles etc. na troca de bioma
##   world_choice_handler()     abre a escolha de +1 buff; DEVE chamar resume_after_choice().
##                              Sem handler => retoma na hora (pool vazio no JS)
##   Campos de buff lidos pelo nucleo: shield_charges, rebound_active, bear_boost_*, post_jump_*,
##   ghost_slow_*, light_steps_mult, invisible_timer, phase_timer, decoy, GhostModel.frozen/trapped/boost_*.

signal game_ended(stats: Dictionary)

var rng: Rng
var level: Object = null
var level_loader: Callable = Callable()
var mech_factory: Callable = Callable()
var on_collectibles: Callable = Callable()
var on_fixed_buffs: Callable = Callable()
var on_transition_reset: Callable = Callable()
var world_choice_handler: Callable = Callable()
var sync_game_state: bool = false   # espelha biome/ciclo/mel/tempo em GameState (cena de jogo liga)

var state: String = "idle"          # "idle" | "playing" | "lose"
var elapsed: float = 0.0
var next_ghost_time: float = 0.0
var run_honey: int = 0
var attr_levels: Dictionary = {}    # {speed_base, jump_cd, jump_ext, double_jump, reroll}

var bear: BearModel
var ghost_sys: GhostSystem
var cycle: BiomeCycle
var jump: JumpState
var honey: HoneySystem
var mech: Object = null
var last_stats: Dictionary = {}

# --- estado de buffs lido pelo nucleo (E4b os escreve) ---
var shield_charges: int = 0
var rebound_active: bool = false
var bear_boost_timer: float = 0.0
var bear_boost_mult: float = 1.0
var post_jump_timer: float = 0.0
var post_jump_spd: float = 0.0
var ghost_slow_timer: float = 0.0
var ghost_slow_mult: float = 1.0
var light_steps_mult: float = 1.0
var invisible_timer: float = 0.0
var phase_timer: float = 0.0
var decoy: Variant = null           # null | {pos: Vector2, life: float, max_life: float}
# maximos (barras do HUD; E4b) e sistemas ligados por BuffSystem.attach / MechFactory.install
var bear_boost_max: float = 0.0
var post_jump_max: float = 0.0
var ghost_slow_max: float = 0.0
var invisible_max: float = 0.0
var phase_max: float = 0.0
var buffs: Object = null            # BuffSystem
var notifications: Array[Dictionary] = []   # addNotif: {text, color, pos, life, max_life, size}


func _init(seed_value: int = -1) -> void:
	rng = Rng.new(seed_value)
	bear = BearModel.new()
	cycle = BiomeCycle.new()
	jump = JumpState.new()
	ghost_sys = GhostSystem.new(self)
	honey = HoneySystem.new(self)


var ghosts: Array[GhostModel]:
	get:
		return ghost_sys.ghosts


# ---------------------------------------------------------------- inicio
## initGame(): bioma 0, urso no spawn, 1o fantasma comum no spawn de fantasma.
func start(p_level: Object) -> void:
	level = p_level
	cycle.reset()
	elapsed = 0.0
	run_honey = 0
	ghost_sys.clear()
	jump.reset()
	honey.reset()
	shield_charges = 0
	rebound_active = false
	bear_boost_timer = 0.0
	bear_boost_mult = 1.0
	post_jump_timer = 0.0
	post_jump_spd = 0.0
	ghost_slow_timer = 0.0
	ghost_slow_mult = 1.0
	light_steps_mult = 1.0
	invisible_timer = 0.0
	phase_timer = 0.0
	decoy = null
	bear_boost_max = 0.0
	post_jump_max = 0.0
	ghost_slow_max = 0.0
	invisible_max = 0.0
	phase_max = 0.0
	notifications.clear()
	bear = BearModel.new()
	var bs: Vector2i = level.call("bear_spawn_cell") as Vector2i
	var gs: Vector2i = level.call("ghost_spawn_cell") as Vector2i
	bear.pos = Units.cell_center(bs.x, bs.y)
	next_ghost_time = biome_effective_spawn_rate()
	ghost_sys.ghosts.append(ghost_sys.make_ghost("comum", Units.cell_center(gs.x, gs.y)))
	_mech_reset()
	recalc_passives()
	state = "playing"
	_sync()
	Events.game_started.emit()


## recalcPassives(): atributos comprados (velocidade, pulo).
func recalc_passives() -> void:
	var lv: int = int(attr_levels.get("speed_base", 0))
	var sp: float = 0.0
	if lv > 0:
		sp = float((((GameState.attrs["defs"] as Dictionary)["speed_base"] as Dictionary)["values"] as Array)[lv - 1])
	bear.speed = bear.base_speed * (1.0 + sp)
	jump.recalc(attr_levels)


# ---------------------------------------------------------------- bioma
func _biome_base(key_cfg: String, key_legacy: String) -> float:
	var cfg: Variant = level.get("config") if level != null else null
	if cfg != null:
		var v: Variant = (cfg as Object).get(key_cfg)
		if v != null:
			return float(v)
	return float((GameState.biomes[cycle.current_biome] as Dictionary)[key_legacy])


func biome_effective_speed() -> float:
	return BiomeCycle.effective_speed(_biome_base("ghost_speed", "ghostSpeed"), cycle.cycle_count)


func biome_effective_spawn_rate() -> float:
	return BiomeCycle.effective_spawn_rate(_biome_base("ghost_spawn_rate", "ghostSpawnRate"), cycle.cycle_count)


## placeBearSafe(): celula de spawn; se parede, celula livre mais proxima do centro (Manhattan).
func place_bear_safe() -> void:
	var s: Vector2i = level.call("bear_spawn_cell") as Vector2i
	var cell: Vector2i = s
	if bool(level.call("is_wall", s.x, s.y)):
		var cr: float = (Units.ROWS - 1) / 2.0
		var cc: float = (Units.COLS - 1) / 2.0
		var bd: float = INF
		for fc in GridCollision.free_cells(level):
			var d: float = absf(fc.y - cr) + absf(fc.x - cc)
			if d < bd:
				bd = d
				cell = fc
	bear.pos = Units.cell_center(cell.x, cell.y)


## randomFreePosAway(from, minD): sorteia entre celulas livres a mais de minD de `from`.
func random_free_pos_away(from: Vector2, min_d: float) -> Vector2:
	var all_cells: Array[Vector2i] = GridCollision.free_cells(level)
	var cells: Array[Vector2i] = []
	for cell in all_cells:
		if Units.cell_center(cell.x, cell.y).distance_to(from) > min_d:
			cells.append(cell)
	var arr: Array[Vector2i] = cells if not cells.is_empty() else all_cells
	var pick: Vector2i = arr[int(rng.randf() * arr.size())]
	return Units.cell_center(pick.x, pick.y)


## executeBiomeTransition().
func execute_biome_transition() -> void:
	cycle.advance()
	if level_loader.is_valid():
		level = level_loader.call(cycle.current_biome)
	if on_transition_reset.is_valid():
		on_transition_reset.call()
	decoy = null
	bear.landing_target = null
	place_bear_safe()
	for g in ghost_sys.ghosts:
		g.pos = random_free_pos_away(bear.pos, Units.TILE * GameplayLits.TRANSITION_GHOST_MIN_CELLS)
		if g.base_class_speed != 0.0:
			g.speed = g.base_class_speed * ghost_sys.diff_mult()   # re-escala por fase
	if ghost_sys.ghosts.is_empty():
		ghost_sys.spawn_ghost(Units.TILE * GameplayLits.TRANSITION_GHOST_MIN_CELLS)
	bear.invuln = maxf(bear.invuln, GameplayLits.TRANSITION_INVULN)
	cycle.start_time = elapsed
	next_ghost_time = elapsed + biome_effective_spawn_rate()
	bear.vel = Vector2.ZERO
	bear.mush_cd = 0.0
	_mech_reset()
	cycle.phase = "choosing"
	Events.biome_changed.emit(cycle.current_biome)
	_sync()
	if world_choice_handler.is_valid():
		world_choice_handler.call()
	else:
		resume_after_choice()


## resumeAfterChoice(): anuncio do bioma so depois da escolha.
func resume_after_choice() -> void:
	cycle.announce_timer = GameplayLits.c("BIOME_ANNOUNCE_DURATION")
	cycle.phase = "playing"
	Events.biome_announce.emit(cycle.current_biome)


# ---------------------------------------------------------------- loop
## Um frame do gameLoop. `input` = vetor de movimento (teclado/joystick).
func step(dt_raw: float, input: Vector2) -> void:
	if state != "playing":
		return
	if cycle.phase == "choosing":
		return   # pausa real durante a escolha
	var dt: float = minf(dt_raw, GameplayLits.MAX_DT)
	elapsed += dt
	if cycle.tick(elapsed):
		execute_biome_transition()
	if cycle.phase == "choosing":
		return   # entrou em escolha agora: nao integra fisica neste frame
	if elapsed >= next_ghost_time:
		ghost_sys.spawn_ghost()
		next_ghost_time = elapsed + biome_effective_spawn_rate()
	bear.move(self, dt, input)
	ghost_sys.move_ghosts(dt)
	if on_collectibles.is_valid():
		on_collectibles.call(dt)
	honey.update(dt)
	update_effects(dt)
	_mech_update(dt)
	honey.update_passive(dt)
	if on_fixed_buffs.is_valid():
		on_fixed_buffs.call(dt)
	if cycle.phase == "warning":
		Events.biome_warning.emit(cycle.remaining(elapsed))
	if cycle.ghost_hide_timer <= 0.0:
		for g in ghost_sys.ghosts:
			if bear.pos.distance_to(g.pos) < bear.size + g.size - Units.px(GameplayLits.CAPTURE_MARGIN):
				if bear.invuln > 0.0:
					continue
				if shield_charges > 0:
					shield_charges -= 1
					notify(I18n.t("fx_shield_name") + " -1", "#9ad8ff", bear.pos - Vector2(0, Units.px(28.0)), 13)
					bear.invuln = GameplayLits.SHIELD_INVULN
					ghost_sys.push_ghost(g)
					continue
				if rebound_active:
					rebound_active = false
					notify(I18n.t("fx_rebound_name") + "!", "#ffd166", bear.pos - Vector2(0, Units.px(28.0)), 14)
					bear.invuln = GameplayLits.REBOUND_INVULN
					ghost_sys.push_ghost(g)
					continue
				end_game()
				return
	_sync()


## updateEffects(dt) (parte de nucleo; HUD/notificacoes ficam para E4c).
func update_effects(dt: float) -> void:
	if bear.frozen > 0.0:
		bear.frozen = maxf(0.0, bear.frozen - dt)
	if bear.invuln > 0.0:
		bear.invuln = maxf(0.0, bear.invuln - dt)
	if bear.poisoned:
		bear.poison_left -= dt
		if bear.poison_left <= 0.0:
			bear.poisoned = false
			bear.poison_left = 0.0
	for g in ghost_sys.ghosts:
		if g.frozen > 0.0:
			g.frozen = maxf(0.0, g.frozen - dt)
		if g.trapped > 0.0:
			g.trapped = maxf(0.0, g.trapped - dt)
		if g.boost_timer > 0.0:
			g.boost_timer = maxf(0.0, g.boost_timer - dt)
	if bear_boost_timer > 0.0:
		bear_boost_timer = maxf(0.0, bear_boost_timer - dt)
	if post_jump_timer > 0.0:
		post_jump_timer = maxf(0.0, post_jump_timer - dt)
	if ghost_slow_timer > 0.0:
		ghost_slow_timer = maxf(0.0, ghost_slow_timer - dt)
	if invisible_timer > 0.0:
		invisible_timer = maxf(0.0, invisible_timer - dt)
	if phase_timer > 0.0:
		phase_timer -= dt
		if phase_timer <= 0.0:
			phase_timer = 0.0
			resolve_landing_inside_wall()
	if decoy != null:
		var dc: Dictionary = decoy as Dictionary
		dc["life"] = float(dc["life"]) - dt
		if float(dc["life"]) <= 0.0:
			decoy = null
	cycle.update_timers(dt)
	if jump.update(dt):
		resolve_landing_inside_wall()
	if bear.landing_target != null:
		var t: Vector2 = bear.landing_target as Vector2
		var delta: Vector2 = t - bear.pos
		var d: float = delta.length()
		if d < Units.px(GameplayLits.LANDING_SNAP) or (not bear.landing_glide and GridCollision.can_move(level, bear.pos.x, bear.pos.y, bear.size)):
			bear.landing_target = null
		else:
			var st: float = minf(d, Units.speed_px_frame_to_px_s(GameplayLits.LANDING_STEP) * dt)
			bear.pos += delta / d * st
	_update_notifications(dt)


func resolve_landing_inside_wall() -> void:
	var t: Variant = GridCollision.nearest_landing_target(level, bear.pos.x, bear.pos.y, bear.size)
	if t != null:
		bear.landing_target = t
		bear.landing_glide = false   # alvo sem `glide` (JS: best = {x,y})


## tryJump() - chamado pelo input (Espaco / botao de pulo).
func try_jump() -> bool:
	if state != "playing":
		return false
	var res: String = jump.try_jump(bear.frozen > 0.0, cycle.phase == "choosing")
	if res != "":
		Events.bear_jumped.emit()
		return true
	return false


# ---------------------------------------------------------------- multiplicadores / ganchos
func bear_speed_mult() -> float:
	var m: float = 1.0
	if bear_boost_timer > 0.0:
		m *= bear_boost_mult
	if post_jump_timer > 0.0:
		m *= 1.0 + post_jump_spd
	return m


func ghost_global_mult() -> float:
	var m: float = light_steps_mult
	if ghost_slow_timer > 0.0:
		m *= ghost_slow_mult
	return m


func is_phasing() -> bool:
	return jump.active or phase_timer > 0.0


## addNotif(text,color,x,y,size): textos flutuantes (o HUD/E4c desenha; game.gd tem placeholder).
func notify(text: String, color: String, pos: Vector2, size: int = 13) -> void:
	notifications.append({"text": text, "color": color, "pos": pos,
		"life": GameplayLits.NOTIF_LIFE, "max_life": GameplayLits.NOTIF_LIFE, "size": size})


func _update_notifications(dt: float) -> void:
	var rise: float = Units.speed_px_frame_to_px_s(GameplayLits.NOTIF_RISE) * dt
	for i in range(notifications.size() - 1, -1, -1):
		var n: Dictionary = notifications[i]
		n["life"] = float(n["life"]) - dt
		n["pos"] = (n["pos"] as Vector2) - Vector2(0, rise)
		if float(n["life"]) <= 0.0:
			notifications.remove_at(i)


func add_honey(amount: int) -> void:
	run_honey += amount
	Events.honey_changed.emit(run_honey)


func _mech_reset() -> void:
	mech = null
	if mech_factory.is_valid():
		mech = mech_factory.call(self, cycle.current_biome) as Object


func _mech_update(dt: float) -> void:
	if mech != null and mech.has_method("update"):
		mech.call("update", self, dt)


func mech_move_bear(dt: float, input: Vector2) -> bool:
	if mech != null and mech.has_method("move_bear"):
		return bool(mech.call("move_bear", self, dt, input))
	return false


func mech_blocks_bear(x: float, y: float) -> bool:
	if mech != null and mech.has_method("blocks_bear"):
		return bool(mech.call("blocks_bear", x, y))
	return false


func mech_speed_mult() -> float:
	if mech != null and mech.has_method("speed_mult"):
		return float(mech.call("speed_mult", self))
	return 1.0


func mech_apply_drift(dt: float) -> void:
	if mech != null and mech.has_method("apply_drift"):
		mech.call("apply_drift", self, dt)


func ghost_alpha() -> float:
	if mech != null and mech.has_method("ghost_alpha"):
		return float(mech.call("ghost_alpha"))
	return 1.0


# ---------------------------------------------------------------- fim
## endGame(): congela a run e publica as estatisticas (tempo sobrevivido, fantasmas, bioma).
## `biome_reached` e o NOME PT do bioma (o JS envia BIOMES[currentBiome].name ao ranking).
func end_game() -> Dictionary:
	state = "lose"
	var b: Dictionary = GameState.biomes[cycle.current_biome] as Dictionary
	last_stats = {
		"seconds": floori(elapsed),
		"ghosts": ghost_sys.ghosts.size(),
		"biome_reached": str(b["name"]),
		"biome_index": cycle.current_biome,
		"cycle": cycle.cycle_count,
		"honey": run_honey,
	}
	_sync()
	Events.game_over.emit(last_stats)
	game_ended.emit(last_stats)
	return last_stats


func _sync() -> void:
	if not sync_game_state:
		return
	GameState.current_biome = cycle.current_biome
	GameState.cycle_count = cycle.cycle_count
	GameState.phases_cleared = cycle.phases_cleared
	GameState.run_honey = run_honey
	GameState.elapsed = elapsed
