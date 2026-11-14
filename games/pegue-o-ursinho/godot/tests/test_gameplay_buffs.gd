extends "res://tests/case.gd"
## Buffs: dados (15 = 9 map + 4 fixed + 2 passive), efeitos exatos de applyMapBuff/triggerFixed, escudo,
## roubo pelo fantasma, spawn/coleta de orbes (SPAWN_INTERVAL_BASE, COLLECT_*), SPRAY_*.

const F: GDScript = preload("res://tests/support/run_factory.gd")

const MAP_IDS: Array = ["speed_temp", "freeze_all", "teleport", "fake_wall", "light_burst", "invisible",
	"slow_time", "light_bomb", "shield"]
const FIXED_IDS: Array = ["ghost_slow", "spirit_trap", "lightning", "decoy"]
const PASSIVE_IDS: Array = ["stomp", "magnet"]


func _b(run: GameRun) -> BuffSystem:
	return run.buffs as BuffSystem


func _add_ghost(run: GameRun, tipo: String, pos: Vector2) -> GhostModel:
	var g: GhostModel = run.ghost_sys.make_ghost(tipo, pos)
	run.ghost_sys.ghosts.append(g)
	return g


func test_data_15_buffs() -> void:
	var all: Array = BuffSystem.all_buffs()
	eq(all.size(), 15, "MAP_BUFFS = 15")
	var maps: int = 0
	var fixeds: int = 0
	var passives: int = 0
	for b: Dictionary in all:
		var t: String = str(b["type"])
		if t == "map":
			maps += 1
			check(MAP_IDS.has(str(b["id"])), "map: " + str(b["id"]))
			check(float(b["selW"]) > 0.0 and float(b["mapW"]) > 0.0, "pesos " + str(b["id"]))
		elif t == "passive":
			passives += 1
			check(PASSIVE_IDS.has(str(b["id"])), "passive: " + str(b["id"]))
			check(float(b["selW"]) > 0.0 and float(b["mapW"]) == 0.0, "pesos passivo " + str(b["id"]))
		else:
			fixeds += 1
			check(FIXED_IDS.has(str(b["id"])), "fixed: " + str(b["id"]))
			check(float(b["selW"]) > 0.0 and float(b["mapW"]) > 0.0, "pesos " + str(b["id"]))
	eq(maps, 9, "9 de mapa")
	eq(fixeds, 4, "4 fixos")
	eq(passives, 2, "2 passivos")
	eq(str(BuffSystem.buff_def("stomp")["rar"]), "incomum", "stomp incomum")
	eq(float(BuffSystem.buff_def("stomp")["selW"]), 9.0, "stomp selW")
	eq(str(BuffSystem.buff_def("magnet")["rar"]), "comum", "magnet comum")
	eq(float(BuffSystem.buff_def("magnet")["selW"]), 12.0, "magnet selW")
	eq(BuffSystem.fixed_interval("ghost_slow"), 12.0, "FIXED_INTERVALS ghost_slow")
	eq(BuffSystem.fixed_interval("spirit_trap"), 12.0, "spirit_trap")
	eq(BuffSystem.fixed_interval("lightning"), 35.0, "lightning")
	eq(BuffSystem.fixed_interval("decoy"), 25.0, "decoy")
	eq(GameplayLits.c("SPRAY_SLOW_MULT"), 0.6, "SPRAY_SLOW_MULT")
	eq(GameplayLits.c("SPRAY_SLOW_DUR"), 4.0, "SPRAY_SLOW_DUR")
	eq(BuffSystem.rarity_color("raro"), "#ff8a8a", "cor raro")
	eq(BuffSystem.rarity_color("incomum"), "#8ab4ff", "cor incomum")
	eq(BuffSystem.rarity_color("comum"), "#7CE0A0", "cor comum")


func test_timed_bear_buffs() -> void:
	var run: GameRun = F.make_full(1)
	var b: BuffSystem = _b(run)
	b.apply_map_buff("speed_temp")
	near(run.bear_boost_timer, 4.0, "speed_temp 4s")
	near(run.bear_boost_mult, 1.8, "speed_temp x1.8")
	near(run.bear_speed_mult(), 1.8, "bearSpeedMult")
	b.apply_map_buff("slow_time")
	near(run.ghost_slow_timer, 4.0, "slow_time 4s")
	near(run.ghost_slow_mult, 0.4, "slow_time x0.4")
	near(run.ghost_global_mult(), 0.4, "ghostGlobalMult")
	b.apply_map_buff("fake_wall")
	near(run.phase_timer, 4.0, "fake_wall 4s")
	check(run.is_phasing(), "atravessa paredes")
	b.apply_map_buff("invisible")
	near(run.invisible_timer, 5.0, "invisible 5s")
	b.apply_map_buff("freeze_all")
	for g in run.ghosts:
		near(g.frozen, 4.0, "freeze_all 4s")


func test_shield_max_one_charge() -> void:
	var run: GameRun = F.make_full(1)
	_b(run).apply_map_buff("shield")
	_b(run).apply_map_buff("shield")
	eq(run.shield_charges, 1, "escudo maximo 1 carga")


func test_teleport() -> void:
	var run: GameRun = F.make_full(3)
	var b: BuffSystem = _b(run)
	var g: GhostModel = run.ghosts[0]
	g.pos = run.bear.pos + Vector2(Units.TILE, 0)
	b.apply_map_buff("teleport")
	check(run.bear.pos.distance_to(g.pos) > Units.TILE * 6.0, "teleporte para longe do fantasma")
	check(GridCollision.can_move(run.level, run.bear.pos.x, run.bear.pos.y, run.bear.size), "teleporte em celula livre")
	eq(run.bear.landing_target, null, "teleporte limpa landingTarget")
	near(run.bear.invuln, 0.5, "invulneravel 0.5s apos teleporte")


func test_light_burst_and_bomb_radius() -> void:
	var run: GameRun = F.make_full(5)
	var b: BuffSystem = _b(run)
	var inside: GhostModel = run.ghosts[0]
	inside.pos = run.bear.pos + Vector2(Units.TILE * 2.0, 0)
	var outside: GhostModel = _add_ghost(run, "comum", run.bear.pos + Vector2(0, Units.TILE * 5.0))
	var out_pos: Vector2 = outside.pos
	b.apply_map_buff("light_burst")
	near(inside.pos.distance_to(run.bear.pos), Units.TILE * 5.0, "empurrao TILE*3.0 alem de 2 celulas", 0.01)
	near(inside.stunned, 1.5, "atingido fica atordoado BURST_STUN")
	eq(outside.pos, out_pos, "fora de 3.5 celulas nao move")
	near(outside.stunned, 0.0, "fora do raio nao atordoa")
	# bomba: elimina so quem esta a < 3.5 celulas
	var run2: GameRun = F.make_full(6)
	var a: GhostModel = run2.ghosts[0]
	a.pos = run2.bear.pos + Vector2(Units.TILE * 3.0, 0)
	var c: GhostModel = _add_ghost(run2, "comum", run2.bear.pos + Vector2(Units.TILE * 3.6, 0))
	_b(run2).apply_map_buff("light_bomb")
	check(not run2.ghosts.has(a), "dentro de 3.5 => eliminado")
	check(run2.ghosts.has(c), "fora de 3.5 => sobrevive")


func test_lightning_and_decoy_and_spirit_trap() -> void:
	var run: GameRun = F.make_full(7)
	var b: BuffSystem = _b(run)
	var g1: GhostModel = run.ghosts[0]
	g1.pos = run.bear.pos + Vector2(Units.TILE * 8, 0)
	var g2: GhostModel = _add_ghost(run, "comum", run.bear.pos + Vector2(Units.TILE * 2, 0))
	b.trigger_fixed("spirit_trap")
	near(g2.trapped, 4.0, "teia no mais proximo 4s")
	near(g1.trapped, 0.0, "o outro livre")
	b.trigger_fixed("lightning")
	check(not run.ghosts.has(g2), "raio elimina o mais proximo")
	check(run.ghosts.has(g1), "o mais longe fica")
	b.trigger_fixed("decoy")
	check(run.decoy != null, "isca criada")
	near(float((run.decoy as Dictionary)["life"]), 6.0, "isca 6s")
	eq((run.decoy as Dictionary)["pos"], run.bear.pos, "isca na posicao do urso")


func test_ghost_steals_orb() -> void:
	var run: GameRun = F.make_full(8)
	var b: BuffSystem = _b(run)
	b.spawn_pool.append((BuffSystem.buff_def("shield")).duplicate())
	b.collectibles.append({"id": "shield", "type": "map", "icon": "", "rar": "raro",
		"pos": Vector2(Units.TILE * 8, Units.TILE * 20), "life": 10.0, "born": 0.0})
	run.bear.pos = Vector2(Units.TILE * 2, Units.TILE * 2)
	var g: GhostModel = run.ghosts[0]
	g.pos = Vector2(Units.TILE * 8, Units.TILE * 20)
	g.frozen = 100.0
	b.update_collectibles(1.0 / 60.0)
	eq(b.collectibles.size(), 0, "orbe roubado some")
	near(g.boost_timer, 4.0, "roubo: +40% por 4s")
	near(g.boost_mult, 1.4, "x1.4")
	eq(run.shield_charges, 0, "urso NAO ganha o buff")
	# fixos nao sao roubados (type 'fixed')
	b.collectibles.append({"id": "decoy", "type": "fixed", "icon": "", "rar": "raro",
		"pos": g.pos, "life": 10.0, "born": 0.0})
	b.update_collectibles(1.0 / 60.0)
	eq(b.collectibles.size(), 1, "fixo nao e roubado")


func test_collect_by_bear_and_expiry() -> void:
	var run: GameRun = F.make_full(9)
	var b: BuffSystem = _b(run)
	run.ghosts[0].frozen = 100.0
	b.collectibles.append({"id": "speed_temp", "type": "map", "icon": "", "rar": "comum",
		"pos": run.bear.pos + Vector2(run.bear.size + Units.px(GameplayLits.c("COLLECT_R")) - 1.0, 0),
		"life": 10.0, "born": 0.0})
	b.update_collectibles(1.0 / 60.0)
	eq(b.collectibles.size(), 0, "coletado a < size+COLLECT_R")
	near(run.bear_boost_mult, 1.8, "efeito aplicado")
	b.collectibles.append({"id": "speed_temp", "type": "map", "icon": "", "rar": "comum",
		"pos": run.bear.pos + Vector2(Units.TILE * 5, 0), "life": 0.01, "born": 0.0})
	b.update_collectibles(0.05)
	eq(b.collectibles.size(), 0, "expira (COLLECT_LIFE)")


func test_spawn_rules() -> void:
	var run: GameRun = F.make_full(10)
	var b: BuffSystem = _b(run)
	near(b.spawn_timer, 8.0, "SPAWN_INTERVAL_BASE")
	b.spawn_collectible()
	eq(b.collectibles.size(), 0, "pool vazio => nada")
	for id in ["speed_temp", "shield", "freeze_all"]:
		b.add_map_to_pool(id)
	b.add_map_to_pool("shield")
	eq(b.spawn_pool.size(), 3, "addMapToPool sem duplicar")
	run.ghosts[0].frozen = 1000.0
	for i in 10:
		b.update_collectibles(1.0)
	check(b.collectibles.size() <= int(GameplayLits.c("MAX_COLLECT")), "MAX_COLLECT=4")
	check(b.collectibles.size() >= 1, "spawnou orbes")
	for col in b.collectibles:
		check(["speed_temp", "shield", "freeze_all"].has(str(col["id"])), "so do pool")
	var maxn: int = 0
	var run2: GameRun = F.make_full(11)
	var b2: BuffSystem = _b(run2)
	b2.add_map_to_pool("freeze_all")
	run2.ghosts[0].frozen = 1000.0
	for i in 400:
		b2.update_collectibles(0.05)
		run2.bear.pos = Vector2(Units.TILE * 1.5, Units.TILE * 1.5)
		maxn = maxi(maxn, b2.collectibles.size())
	check(maxn <= 4, "nunca passa de 4 orbes")
	for col in b2.collectibles:
		check((col["pos"] as Vector2).distance_to(run2.bear.pos) >= Units.TILE * 3.0 - 0.01 or float(col["life"]) < 9.0, "spawn >= 3 celulas do urso")


func test_fixed_buffs_intervals() -> void:
	var run: GameRun = F.make_full(12)
	var b: BuffSystem = _b(run)
	b.activate_fixed("ghost_slow")
	b.activate_fixed("ghost_slow")
	eq(b.fixed_buffs.size(), 1, "activateFixed idempotente")
	near(float(b.fixed_timers["ghost_slow"]), 12.0, "timer = FIXED_INTERVALS")
	b.update_fixed(11.9)
	near(run.ghost_slow_timer, 0.0, "ainda nao disparou")
	b.update_fixed(0.2)
	near(run.ghost_slow_timer, 4.0, "SPRAY_SLOW_DUR=4")
	near(run.ghost_slow_mult, 0.6, "SPRAY_SLOW_MULT=0.6")
	near(float(b.fixed_timers["ghost_slow"]), 12.0, "timer reiniciado")
	# raio a cada 35s elimina o mais proximo
	b.activate_fixed("lightning")
	var extra: GhostModel = _add_ghost(run, "comum", run.bear.pos + Vector2(Units.TILE * 3, 0))
	var n0: int = run.ghosts.size()
	b.update_fixed(34.9)
	eq(run.ghosts.size(), n0, "raio ainda nao")
	b.update_fixed(0.2)
	eq(run.ghosts.size(), n0 - 1, "raio eliminou 1")
	check(not run.ghosts.has(extra), "o mais proximo")
	# isca a cada 25s; teia a cada 12s
	b.activate_fixed("decoy")
	b.activate_fixed("spirit_trap")
	b.update_fixed(25.1)
	check(run.decoy != null, "isca lancada aos 25s")
	if not run.ghosts.is_empty():
		var any_trapped: bool = false
		for g in run.ghosts:
			any_trapped = any_trapped or g.trapped > 0.0
		check(any_trapped, "teia prendeu um fantasma")


func test_run_loop_runs_buffs() -> void:
	# integracao: o loop da GameRun dispara coleta e fixos
	var run: GameRun = F.make_full(13)
	var b: BuffSystem = _b(run)
	b.activate_fixed("decoy")
	b.fixed_timers["decoy"] = 0.5
	F.advance(run, 1.0, Vector2.ZERO, true)
	check(run.decoy != null, "decoy via on_fixed_buffs")
	b.collectibles.append({"id": "shield", "type": "map", "icon": "", "rar": "raro",
		"pos": run.bear.pos, "life": 10.0, "born": 0.0})
	F.advance(run, 0.1, Vector2.ZERO, true)
	eq(run.shield_charges, 1, "orbe coletado via on_collectibles")
	check(not run.notifications.is_empty(), "notificacao criada (addNotif)")


func test_shield_absorbs_capture() -> void:
	var run: GameRun = F.make_full(14)
	_b(run).apply_map_buff("shield")
	var g: GhostModel = run.ghosts[0]
	g.pos = run.bear.pos
	g.frozen = 100.0
	run.step(1.0 / 60.0, Vector2.ZERO)
	eq(run.state, "playing", "escudo absorveu")
	eq(run.shield_charges, 0, "carga gasta")
	near(run.bear.invuln, 0.9, "invuln 0.9", 0.05)
	# sem escudo e sem pulo/invuln: captura (o rebote foi removido)
	run.bear.invuln = 0.0
	g.pos = run.bear.pos
	run.step(1.0 / 60.0, Vector2.ZERO)
	eq(run.state, "lose", "sem escudo o fantasma pega")
