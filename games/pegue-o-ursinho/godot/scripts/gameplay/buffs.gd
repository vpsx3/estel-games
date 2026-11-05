class_name BuffSystem
extends RefCounted
## Buffs da run. Porta MAP_BUFFS / FIXED_INTERVALS / SPRAY_*, applyMapBuff, activateFixed,
## triggerFixed, spawnCollectible, updateCollectibles, weightedPick/One, selectablePool,
## addMapToPool, openSelection/togglePick/startRun e openWorldChoice/pickWorldBuff/worldReroll.
##
## Uso:  var b := BuffSystem.new(run); b.attach()  (liga os ganchos da GameRun)
##       b.open_selection() -> 5 opcoes; b.toggle_pick(id) ate 3; b.start_run(level)
##       (equivale a startRun: initGame + ativa os fixos escolhidos)
## Escolha de +1 buff a cada troca de mundo: o handler da GameRun chama open_world_choice();
## a UI (E4c) le `world_options`, chama pick_world_buff(id) / world_reroll(); ambos terminam em
## run.resume_after_choice(). Com auto_choice = true (placeholder sem UI) escolhe a 1a opcao.

signal selection_opened(options: Array)
signal world_choice_opened(options: Array)
signal world_choice_closed()

var run: GameRun
var auto_choice: bool = false

var collectibles: Array[Dictionary] = []   # {id, type, icon, rar, pos, life, born}
var spawn_pool: Array[Dictionary] = []     # buffs de MAPA que podem aparecer no mapa
var spawn_timer: float = 0.0
var fixed_buffs: Array[String] = []        # fixos ativos nesta run
var fixed_timers: Dictionary = {}          # id -> s ate o proximo disparo
var item_cd_reduction: float = 0.0         # passivo removido no JS; fica 0 (formula preservada)
var build_ids: Array[String] = []          # ordem em que os buffs foram obtidos (buildIcons)

# selecao pre-run
var selection_options: Array = []          # 5 dicts de MAP_BUFFS
var selection_picks: Array[String] = []    # ids, ate 3
# escolha entre biomes
var world_options: Array = []
var world_choice_active: bool = false
var reroll_used: bool = false


func _init(p_run: GameRun) -> void:
	run = p_run


## Liga os ganchos da GameRun (updateCollectibles, buffs fixos, troca de bioma, escolha +1).
func attach() -> void:
	run.buffs = self
	run.on_collectibles = update_collectibles
	run.on_fixed_buffs = update_fixed
	run.on_transition_reset = on_transition_reset
	run.world_choice_handler = open_world_choice


# ---------------------------------------------------------------- dados
static func all_buffs() -> Array:
	return GameState.buffs["map_buffs"] as Array


static func buff_def(id: String) -> Dictionary:
	for b: Dictionary in all_buffs():
		if str(b["id"]) == id:
			return b
	return {}


static func fixed_interval(id: String) -> float:
	return float((GameState.buffs["fixed_intervals"] as Dictionary)[id])


## Cor da raridade (rarColor).
static func rarity_color(rar: String) -> String:
	if rar == "raro":
		return "#ff8a8a"
	if rar == "incomum":
		return "#8ab4ff"
	return "#7CE0A0"


## selectablePool(): universo selecionavel; exclui fixos ja ativos.
func selectable_pool() -> Array:
	var out: Array = []
	for b: Dictionary in all_buffs():
		if str(b["type"]) == "fixed" and fixed_buffs.has(str(b["id"])):
			continue
		out.append(b)
	return out


## addMapToPool(id)
func add_map_to_pool(id: String) -> void:
	for b in spawn_pool:
		if str(b["id"]) == id:
			return
	var def: Dictionary = buff_def(id)
	if not def.is_empty():
		spawn_pool.append(def.duplicate())


# ---------------------------------------------------------------- selecao pre-run (5 -> 3)
## openSelection(): zera os fixos e sorteia 5 opcoes por selW.
func open_selection() -> Array:
	selection_picks.clear()
	fixed_buffs.clear()
	fixed_timers.clear()
	selection_options = run.rng.weighted_pick(selectable_pool(), "selW", GameplayLits.PRE_RUN_OPTIONS)
	selection_opened.emit(selection_options)
	return selection_options


## togglePick(): marca/desmarca; no maximo 3. Retorna true se a escolha mudou.
func toggle_pick(id: String) -> bool:
	var i: int = selection_picks.find(id)
	if i >= 0:
		selection_picks.remove_at(i)
		return true
	if selection_picks.size() >= GameplayLits.PRE_RUN_PICKS:
		return false
	var offered: bool = false
	for b: Dictionary in selection_options:
		if str(b["id"]) == id:
			offered = true
	if not offered:
		return false
	selection_picks.append(id)
	return true


func can_start() -> bool:
	return selection_picks.size() == GameplayLits.PRE_RUN_PICKS


## Escolhe as 3 primeiras opcoes (placeholder sem UI / testes).
func auto_pick() -> void:
	selection_picks.clear()
	for b: Dictionary in selection_options:
		if selection_picks.size() < GameplayLits.PRE_RUN_PICKS:
			selection_picks.append(str(b["id"]))


## startRun(): pool de spawn = buffs de mapa escolhidos; initGame; ativa os fixos escolhidos;
## recalcPassives. Exige 3 picks.
func start_run(level: Object) -> bool:
	if not can_start():
		return false
	var map_picks: Array[String] = []
	var fixed_picks: Array[String] = []
	for id in selection_picks:
		if str(buff_def(id)["type"]) == "fixed":
			fixed_picks.append(id)
		else:
			map_picks.append(id)
	spawn_pool.clear()
	for b: Dictionary in all_buffs():   # ordem de MAP_BUFFS, como o filter do JS
		if str(b["type"]) == "map" and map_picks.has(str(b["id"])):
			spawn_pool.append(b.duplicate())
	build_ids.assign(selection_picks)
	run.start(level)         # initGame()
	reset_run_state()
	for id in fixed_picks:
		activate_fixed(id)
	run.recalc_passives()
	for id in selection_picks:
		Events.buff_selected.emit(id)
	return true


## Parte de initGame que zera os buffs (collectibles, spawnTimer, fixos).
func reset_run_state() -> void:
	collectibles.clear()
	spawn_timer = GameplayLits.c("SPAWN_INTERVAL_BASE")
	fixed_buffs.clear()
	fixed_timers.clear()
	item_cd_reduction = 0.0
	world_choice_active = false
	reroll_used = false


# ---------------------------------------------------------------- escolha +1 a cada troca de mundo
func open_world_choice() -> void:
	reroll_used = false
	if selectable_pool().is_empty():   # pool esgotado: pula a escolha
		run.resume_after_choice()
		return
	world_options = run.rng.weighted_pick(selectable_pool(), "selW", GameplayLits.WORLD_CHOICE_OPTIONS)
	world_choice_active = true
	world_choice_opened.emit(world_options)
	if auto_choice:
		pick_world_buff(str((world_options[0] as Dictionary)["id"]))


## O botao de reroll so aparece com o atributo comprado.
func reroll_enabled() -> bool:
	return int(run.attr_levels.get("reroll", 0)) > 0


func pick_world_buff(id: String) -> void:
	if not world_choice_active:
		return
	var def: Dictionary = buff_def(id)
	if def.is_empty():
		return
	if str(def["type"]) == "fixed":
		activate_fixed(id)
	else:
		add_map_to_pool(id)   # passa a spawnar no mapa daqui pra frente
	build_ids.append(id)
	Events.buff_selected.emit(id)
	world_choice_active = false
	world_options = []
	world_choice_closed.emit()
	run.resume_after_choice()


## worldReroll(): 1 por escolha de mundo. Retorna false se nao permitido.
func world_reroll() -> bool:
	if not world_choice_active or reroll_used or not reroll_enabled():
		return false
	reroll_used = true
	world_options = run.rng.weighted_pick(selectable_pool(), "selW", GameplayLits.WORLD_CHOICE_OPTIONS)
	world_choice_opened.emit(world_options)
	return true


func on_transition_reset() -> void:
	collectibles.clear()


# ---------------------------------------------------------------- buffs fixos
func activate_fixed(id: String) -> void:
	if fixed_buffs.has(id):
		return
	fixed_buffs.append(id)
	fixed_timers[id] = fixed_interval(id)


## triggerFixed(id)
func trigger_fixed(id: String) -> void:
	match id:
		"ghost_slow":
			var dur: float = GameplayLits.c("SPRAY_SLOW_DUR")
			run.ghost_slow_timer = dur
			run.ghost_slow_mult = GameplayLits.c("SPRAY_SLOW_MULT")
			run.ghost_slow_max = dur
			run.notify(I18n.buff_name(id), "#bfe0ff", run.bear.pos - Vector2(0, Units.px(30.0)))
		"spirit_trap":
			var g: GhostModel = run.ghost_sys.nearest_ghost()
			if g != null:
				g.trapped = float(GameplayLits.BUFF_FX["spirit_trap"]["dur"])
		"lightning":
			_eliminate(run.ghost_sys.nearest_ghost())
		"decoy":
			_make_decoy()
	Events.buff_activated.emit(id)


## Timers dos buffs fixos (trecho do gameLoop).
func update_fixed(dt: float) -> void:
	for id in fixed_buffs.duplicate():
		fixed_timers[id] = float(fixed_timers[id]) - dt
		if float(fixed_timers[id]) <= 0.0:
			trigger_fixed(id)
			fixed_timers[id] = fixed_interval(id)


# ---------------------------------------------------------------- buffs de mapa
func _eliminate(g: GhostModel) -> void:
	if g == null:
		return
	run.ghost_sys.ghosts.erase(g)
	Events.ghost_eliminated.emit(g.tipo)


func _make_decoy() -> void:
	var life: float = float(GameplayLits.BUFF_FX["decoy"]["dur"])
	run.decoy = {"pos": run.bear.pos, "life": life, "max_life": life}


## applyMapBuff(id, target): `ghost` null = o urso coletou; senao o fantasma ROUBOU (+40% vel. 4s).
func apply_map_buff(id: String, ghost: GhostModel = null) -> void:
	var def: Dictionary = buff_def(id)
	if def.is_empty():
		return
	var fx: Dictionary = GameplayLits.BUFF_FX
	var bear: BearModel = run.bear
	if ghost != null:
		ghost.boost_timer = float((fx["steal"] as Dictionary)["dur"])
		ghost.boost_mult = float((fx["steal"] as Dictionary)["mult"])
		run.notify(I18n.t("notif_stolen"), "#ff8a8a", ghost.pos - Vector2(0, Units.px(26.0)), 12)
		return
	run.notify(I18n.buff_name(id), rarity_color(str(def["rar"])), bear.pos - Vector2(0, Units.px(30.0)), 15)
	var fx_text: String = I18n.map_fx(id)
	if fx_text != "":
		run.notify(fx_text, "#cfe6ff", bear.pos - Vector2(0, Units.px(14.0)), 11)
	match id:
		"speed_temp":
			run.bear_boost_timer = float((fx["speed_temp"] as Dictionary)["dur"])
			run.bear_boost_mult = float((fx["speed_temp"] as Dictionary)["mult"])
			run.bear_boost_max = run.bear_boost_timer
		"dash":
			run.bear_boost_timer = float((fx["dash"] as Dictionary)["dur"])
			run.bear_boost_mult = float((fx["dash"] as Dictionary)["mult"])
			run.bear_boost_max = run.bear_boost_timer
		"freeze_all":
			for g in run.ghost_sys.ghosts:
				g.frozen = maxf(g.frozen, float((fx["freeze_all"] as Dictionary)["dur"]))
		"ghost_slow":
			run.ghost_slow_timer = float((fx["ghost_slow"] as Dictionary)["dur"])
			run.ghost_slow_mult = float((fx["ghost_slow"] as Dictionary)["mult"])
			run.ghost_slow_max = run.ghost_slow_timer
		"slow_time":
			run.ghost_slow_timer = float((fx["slow_time"] as Dictionary)["dur"])
			run.ghost_slow_mult = float((fx["slow_time"] as Dictionary)["mult"])
			run.ghost_slow_max = run.ghost_slow_timer
		"teleport":
			var near_g: GhostModel = run.ghost_sys.nearest_ghost()
			var from: Vector2 = near_g.pos if near_g != null else bear.pos
			bear.pos = run.random_free_pos_away(from, Units.TILE * GameplayLits.TELEPORT_MIN_CELLS)
			bear.landing_target = null
		"swap":
			var far_g: GhostModel = run.ghost_sys.farthest_ghost()
			if far_g != null:
				var bp: Vector2 = bear.pos
				bear.pos = far_g.pos
				far_g.pos = bp
				run.ghost_sys.clamp_ghost(far_g)
		"spirit_trap":
			var tg: GhostModel = run.ghost_sys.nearest_ghost()
			if tg != null:
				tg.trapped = float((fx["spirit_trap"] as Dictionary)["dur"])
		"fake_wall":
			run.phase_timer = float((fx["fake_wall"] as Dictionary)["dur"])
			run.phase_max = run.phase_timer
		"invisible":
			run.invisible_timer = float((fx["invisible"] as Dictionary)["dur"])
			run.invisible_max = run.invisible_timer
		"light_burst":
			for g in run.ghost_sys.ghosts:
				var delta: Vector2 = g.pos - bear.pos
				var d: float = delta.length()
				if d == 0.0:
					d = 1.0
				if d < Units.TILE * GameplayLits.BURST_RADIUS_CELLS:
					g.pos += delta / d * Units.TILE * GameplayLits.BURST_PUSH_CELLS
					run.ghost_sys.clamp_ghost(g)
		"lightning":
			_eliminate(run.ghost_sys.nearest_ghost())
		"light_bomb":
			var arr: Array[GhostModel] = run.ghost_sys.ghosts
			for i in range(arr.size() - 1, -1, -1):
				if arr[i].pos.distance_to(bear.pos) < Units.TILE * GameplayLits.BURST_RADIUS_CELLS:
					var gone: GhostModel = arr[i]
					arr.remove_at(i)
					Events.ghost_eliminated.emit(gone.tipo)
		"rebound":
			run.rebound_active = true
		"decoy":
			_make_decoy()
		"shield":
			run.shield_charges = mini(GameplayLits.MAX_SHIELD_CHARGES, run.shield_charges + 1)   # max 1 carga
	Events.buff_activated.emit(id)


# ---------------------------------------------------------------- spawn e coleta no mapa
## spawnCollectible()
func spawn_collectible() -> void:
	if spawn_pool.is_empty():
		return
	var buff: Dictionary = run.rng.weighted_one(spawn_pool, "mapW") as Dictionary
	var all_cells: Array[Vector2i] = GridCollision.free_cells(run.level)
	var cells: Array[Vector2i] = []
	for cell in all_cells:
		var ctr: Vector2 = Units.cell_center(cell.x, cell.y)
		if ctr.distance_to(run.bear.pos) < Units.TILE * GameplayLits.COLLECT_BEAR_MIN_CELLS:
			continue
		var close: bool = false
		for col in collectibles:
			if (col["pos"] as Vector2).distance_to(ctr) < Units.TILE * GameplayLits.COLLECT_SPACING_CELLS:
				close = true
				break
		if not close:
			cells.append(cell)
	if cells.is_empty():
		cells = all_cells
	if cells.is_empty():
		return
	var pick: Vector2i = cells[int(run.rng.randf() * cells.size())]
	collectibles.append({
		"id": buff["id"], "type": buff["type"], "icon": buff["icon"], "rar": buff["rar"],
		"pos": Units.cell_center(pick.x, pick.y), "life": GameplayLits.c("COLLECT_LIFE"),
		"born": run.rng.randf() * GameplayLits.COLLECT_BORN_RANGE,
	})


## updateCollectibles(dt): spawn periodico, expira, coleta pelo urso ou ROUBO pelo fantasma.
func update_collectibles(dt: float) -> void:
	spawn_timer -= dt
	if spawn_timer <= 0.0:
		if collectibles.size() < int(GameplayLits.c("MAX_COLLECT")):
			spawn_collectible()
		spawn_timer = GameplayLits.c("SPAWN_INTERVAL_BASE") * (1.0 - item_cd_reduction)
	var collect_r: float = Units.px(GameplayLits.c("COLLECT_R"))
	for i in range(collectibles.size() - 1, -1, -1):
		var col: Dictionary = collectibles[i]
		col["life"] = float(col["life"]) - dt
		if float(col["life"]) <= 0.0:
			collectibles.remove_at(i)
			continue
		var cpos: Vector2 = col["pos"] as Vector2
		if run.bear.pos.distance_to(cpos) < run.bear.size + collect_r:
			collectibles.remove_at(i)
			apply_map_buff(str(col["id"]))
			continue
		if str(col["type"]) == "map":
			for g in run.ghost_sys.ghosts:
				if g.pos.distance_to(cpos) < g.size + collect_r:
					collectibles.remove_at(i)
					apply_map_buff(str(col["id"]), g)   # fantasma roubou: nerf (+40% vel. 4s)
					break
