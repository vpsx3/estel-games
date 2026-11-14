extends "res://tests/case.gd"
## Rebalanceamento final (docs/balanceamento.md): pulo desvia, teto de fantasmas, graca de spawn,
## minPhase, teto de dificuldade, teleporte seguro, invisibilidade, atordoamento, lentidao,
## stomp, magnet, pool/ritmo de orbes, mel por fase, gelo proporcional, VFX novos e textos.

const F: GDScript = preload("res://tests/support/run_factory.gd")
const DT: float = 1.0 / 60.0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _b(run: GameRun) -> BuffSystem:
	return run.buffs as BuffSystem


func _add_ghost(run: GameRun, tipo: String, pos: Vector2) -> GhostModel:
	var g: GhostModel = run.ghost_sys.make_ghost(tipo, pos)
	run.ghost_sys.ghosts.append(g)
	return g


## Preenche com fantasmas inertes (presos, longe do urso) ate o tamanho `n`.
func _fill_ghosts(run: GameRun, n: int) -> void:
	var i: int = 0
	while run.ghosts.size() < n:
		var g: GhostModel = _add_ghost(run, "comum", Units.cell_center(2 + i % 14, 26 - (i / 14) * 2))
		g.trapped = 10000.0
		i += 1


# ------------------------------------------------------------- 1. pulo desvia + invuln no pouso
func test_jump_dodges_ghosts_and_lands_invulnerable() -> void:
	var run: GameRun = F.make_run(1)
	var landed: Array = []
	var cb: Callable = func() -> void: landed.append(true)
	Events.bear_landed.connect(cb)
	var g: GhostModel = run.ghosts[0]
	g.pos = run.bear.pos
	g.frozen = 100.0
	run.jump.active = true
	run.jump.timer = 5.0
	run.step(0.0, Vector2.ZERO)
	eq(run.state, "playing", "em pulo o fantasma nao captura")
	run.jump.timer = 0.01
	run.step(0.02, Vector2.ZERO)
	Events.bear_landed.disconnect(cb)
	check(not run.jump.active, "pousou")
	eq(landed.size(), 1, "Events.bear_landed emitido")
	near(run.bear.invuln, 0.3, "invulneravel 0.3s no pouso", 0.001)
	eq(run.state, "playing", "pouso sobre o fantasma nao captura (invuln)")
	run.bear.invuln = 0.0
	run.step(0.0, Vector2.ZERO)
	eq(run.state, "lose", "sem pulo e sem invuln captura")


# ------------------------------------------------------------- 2. teto de fantasmas
func test_ghost_cap_formula() -> void:
	var run: GameRun = F.make_run(1)
	eq(run.ghost_cap(), 5, "fase 0 => 5")
	run.cycle.phases_cleared = 3
	eq(run.ghost_cap(), 8, "3 fases => 8")
	run.cycle.phases_cleared = 30
	eq(run.ghost_cap(), 14, "teto por ciclo 0 => 14")
	run.cycle.cycle_count = 1
	eq(run.ghost_cap(), 16, "ciclo 1 => 16")
	run.cycle.cycle_count = 9
	eq(run.ghost_cap(), 18, "teto absoluto 18")


func test_periodic_spawn_respects_cap() -> void:
	var run: GameRun = F.make_run(3)
	_fill_ghosts(run, run.ghost_cap())
	run.next_ghost_time = 0.0
	run.bear.invuln = 100.0
	run.step(DT, Vector2.ZERO)
	eq(run.ghosts.size(), 5, "no teto: nao cria")
	check(run.next_ghost_time > run.elapsed + 5.0, "timer reinicia mesmo sem criar")
	run.ghosts.pop_back()
	run.next_ghost_time = 0.0
	run.bear.invuln = 100.0
	run.step(DT, Vector2.ZERO)
	eq(run.ghosts.size(), 5, "abaixo do teto: cria")
	near(run.ghosts[run.ghosts.size() - 1].spawn_timer, 0.8 - 0.0, "novo fantasma nasce com graca", 0.05)


func test_windows_respect_cap_and_grace() -> void:
	var run: GameRun = F.make_mech_run(5, true, 4)
	var m: MechWindows = run.mech as MechWindows
	var cell: Vector2i = Vector2i(5, 10)
	m.windows = [{"cell": cell, "armed": false, "t": 0.0, "cd": 0.0, "radius": 3.0, "telegraph": 1.2, "cd_max": 15.0}]
	run.bear.pos = Units.cell_center(cell.x, cell.y) + Vector2(Units.TILE * 2.0, 0)
	_fill_ghosts(run, run.ghost_cap())
	m.update(run, 1.3)
	eq(run.ghosts.size(), 5, "janela no teto: nao cria")
	near(float(m.windows[0]["cd"]), 15.0, "mas a janela entra em cooldown")
	run.ghosts.pop_back()
	m.windows[0]["cd"] = 0.0
	m.update(run, 1.3)
	eq(run.ghosts.size(), 5, "janela abaixo do teto: cria")
	near(run.ghosts[run.ghosts.size() - 1].spawn_timer, 0.8, "fantasma da janela com graca")


# ------------------------------------------------------------- 3. graca de spawn
func test_spawn_grace() -> void:
	var run: GameRun = F.make_run(2)
	near(run.ghosts[0].spawn_timer, 0.0, "1o fantasma da run sem graca")
	var g: GhostModel = run.ghost_sys.spawn_ghost()
	near(g.spawn_timer, 0.8, "fantasma criado depois tem graca")
	g.pos = Vector2(300, 300)
	run.bear.pos = Vector2(100, 100)
	run.ghost_sys.move_ghosts(0.1)
	eq(g.pos, Vector2(300, 300), "na graca nao se move")
	# nao captura
	run.ghosts[0].frozen = 100.0
	g.pos = run.bear.pos
	run.step(0.0, Vector2.ZERO)
	eq(run.state, "playing", "na graca nao captura")
	# nao envenena
	var v: GhostModel = run.ghost_sys.make_ghost("venenoso", run.bear.pos + Vector2(10, 0))
	v.spawn_timer = 0.5
	run.ghosts.append(v)
	run.ghost_sys.move_ghosts(0.0)
	check(not run.bear.poisoned, "na graca nao envenena")
	# nao rouba orbe
	var rb: GameRun = F.make_full(8)
	var bs: BuffSystem = _b(rb)
	var gg: GhostModel = rb.ghosts[0]
	gg.frozen = 100.0
	gg.spawn_timer = 0.5
	rb.bear.pos = Vector2(Units.TILE * 2, Units.TILE * 2)
	bs.collectibles.append({"id": "shield", "type": "map", "icon": "", "rar": "raro", "pos": gg.pos, "life": 10.0, "born": 0.0})
	bs.update_collectibles(DT)
	eq(bs.collectibles.size(), 1, "na graca nao rouba orbe")
	# a graca expira
	run.update_effects(0.9)
	near(g.spawn_timer, 0.0, "graca acaba")


func test_ghost_view_alpha_during_grace() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/gameplay/ghost_view.gd")
	check("spawn_timer" in src and "lerpf(0.25" in src, "ghost_view: alpha 0.25 -> 1 na graca")


# ------------------------------------------------------------- 4/5. minPhase e teto de dificuldade
func test_min_phase_gates_types() -> void:
	var run: GameRun = F.make_run(42)
	var allowed: Dictionary = {0: ["comum"], 1: ["comum", "rapido", "pesado"], 2: ["comum", "rapido", "pesado", "errante"],
		3: ["comum", "rapido", "pesado", "errante", "venenoso"]}
	for ph: int in allowed:
		run.cycle.phases_cleared = ph
		var seen: Dictionary = {}
		for i in 4000:
			var t: String = run.ghost_sys.weighted_random()
			check((allowed[ph] as Array).has(t), "fase %d nao libera %s" % [ph, t])
			seen[t] = true
		eq(seen.size(), (allowed[ph] as Array).size(), "fase %d: todos os liberados aparecem" % ph)


func test_diff_mult_cap() -> void:
	var run: GameRun = F.make_run(1)
	run.cycle.cycle_count = 5
	run.cycle.phases_cleared = 50
	near(run.ghost_sys.diff_mult(), 0.93, "diff_mult limitado a 0.93")
	run.cycle.cycle_count = 0
	run.cycle.phases_cleared = 0
	near(run.ghost_sys.diff_mult(), 0.31, "abaixo do teto nao muda")


# ------------------------------------------------------------- 5. atordoamento
func test_stun_blocks_movement_and_decays() -> void:
	var run: GameRun = F.make_run(1)
	var g: GhostModel = run.ghosts[0]
	run.bear.pos = Vector2(100, 100)
	g.pos = Vector2(300, 300)
	g.stunned = 1.0
	run.ghost_sys.move_ghosts(0.1)
	eq(g.pos, Vector2(300, 300), "atordoado nao se move")
	var other: GhostModel = _add_ghost(run, "comum", Vector2(305, 300))
	run.ghost_sys.resolve_collisions()
	eq(g.pos, Vector2(300, 300), "atordoado nao e empurrado na separacao")
	check(other.pos != Vector2(305, 300), "o outro se afasta")
	run.update_effects(0.4)
	near(g.stunned, 0.6, "stunned decrementa", 0.001)
	run.update_effects(1.0)
	near(g.stunned, 0.0, "stunned zera")


# ------------------------------------------------------------- 6. lentidao nao se sobrescreve
func test_slow_does_not_overwrite() -> void:
	var run: GameRun = F.make_full(1)
	var b: BuffSystem = _b(run)
	b.trigger_fixed("ghost_slow")   # 0.6 por 4s
	near(run.ghost_slow_mult, 0.6, "spray x0.6")
	near(run.ghost_slow_timer, 4.0, "spray 4s")
	run.ghost_slow_timer = 1.0
	b.apply_map_buff("slow_time")   # 0.4 por 4s: menor mult, maior tempo
	near(run.ghost_slow_mult, 0.4, "mult = min")
	near(run.ghost_slow_timer, 4.0, "timer = max")
	near(run.ghost_slow_max, 4.0, "max = max")
	run.ghost_slow_timer = 3.0
	b.trigger_fixed("ghost_slow")   # 0.6 por 4s com 0.4 ativo
	near(run.ghost_slow_mult, 0.4, "o menor mult permanece")
	near(run.ghost_slow_timer, 4.0, "tempo estendido")
	run.ghost_slow_timer = 0.0
	b.trigger_fixed("ghost_slow")
	near(run.ghost_slow_mult, 0.6, "sem slow ativo: aplica o novo")


# ------------------------------------------------------------- 7. teleporte seguro
func test_safest_free_pos() -> void:
	var run: GameRun = F.make_run(5)
	run.ghosts.clear()
	var free: Array[Vector2i] = GridCollision.free_cells(run.level)
	check(GridCollision.can_move(run.level, run.safest_free_pos().x, run.safest_free_pos().y, run.bear.size), "sem fantasmas: celula livre")
	_add_ghost(run, "comum", Units.cell_center(1, 1))
	_add_ghost(run, "comum", Units.cell_center(16, 1))
	_add_ghost(run, "comum", Units.cell_center(1, 28))
	var scores: Array = []
	for c in free:
		var p: Vector2 = Units.cell_center(c.x, c.y)
		var md: float = INF
		for g in run.ghosts:
			md = minf(md, p.distance_to(g.pos))
		scores.append(md)
	scores.sort()
	scores.reverse()
	var fifth: float = float(scores[4])
	for i in 40:
		var p2: Vector2 = run.safest_free_pos()
		var md2: float = INF
		for g in run.ghosts:
			md2 = minf(md2, p2.distance_to(g.pos))
		check(md2 >= fifth - 0.01, "entre as 5 melhores (md=%.1f quinta=%.1f)" % [md2, fifth])
		check(GridCollision.can_move(run.level, p2.x, p2.y, run.bear.size), "celula livre")
	# determinismo (rng da run)
	var a: GameRun = F.make_run(9)
	var b: GameRun = F.make_run(9)
	eq(a.safest_free_pos(), b.safest_free_pos(), "determinismo com a mesma seed")


func test_teleport_buff_and_portal_are_safe_and_invulnerable() -> void:
	var run: GameRun = F.make_full(3)
	run.ghosts[0].pos = Units.cell_center(1, 1)
	_b(run).apply_map_buff("teleport")
	check(run.bear.pos.distance_to(Units.cell_center(1, 1)) > Units.TILE * 15.0, "teleporte vai para longe do fantasma")
	near(run.bear.invuln, 0.5, "invuln 0.5 no teleporte")
	var vr: GameRun = F.make_mech_run(9, true, 7)
	var m: MechVoid = vr.mech as MechVoid
	var cell: Vector2i = Vector2i(1, 1)
	vr.bear.pos = Units.cell_center(cell.x, cell.y)
	vr.ghosts[0].pos = Units.cell_center(2, 2)
	m.portals = [cell]
	m.portal_cd = 0.0
	m.update(vr, DT)
	check(m.portal_cd > 0.0, "portal disparou")
	check(vr.bear.pos.distance_to(Units.cell_center(2, 2)) > Units.TILE * 15.0, "portal manda para ponto seguro")
	near(vr.bear.invuln, 0.5, "invuln 0.5 no portal")


# ------------------------------------------------------------- 8. invisibilidade
func test_invisibility_wander_no_capture_no_poison_end_invuln() -> void:
	var run: GameRun = F.make_run(2)
	var g: GhostModel = run.ghosts[0]
	run.bear.pos = Vector2(100, 100)
	g.pos = Vector2(300, 300)
	run.invisible_timer = 5.0
	var p0: Vector2 = g.pos
	for i in 20:
		run.ghost_sys.move_ghosts(DT)
	check(g.pos != p0, "invisivel: fantasmas vagam (nao ficam parados)")
	g.pos = run.bear.pos
	run.step(0.0, Vector2.ZERO)
	eq(run.state, "playing", "invisivel: nao captura")
	var v: GhostModel = run.ghost_sys.make_ghost("venenoso", run.bear.pos + Vector2(8, 0))
	run.ghosts.append(v)
	run.ghost_sys.move_ghosts(DT)
	check(not run.bear.poisoned, "invisivel: nao envenena")
	run.bear.invuln = 0.0
	run.invisible_timer = 0.01
	run.step(0.05, Vector2.ZERO)
	near(run.invisible_timer, 0.0, "invisibilidade acabou")
	near(run.bear.invuln, 0.6, "invuln 0.6 ao fim", 0.001)


# ------------------------------------------------------------- 9. explosao de luz atordoa
func test_burst_stuns_and_pushes() -> void:
	var run: GameRun = F.make_full(5)
	var g: GhostModel = run.ghosts[0]
	g.pos = run.bear.pos + Vector2(Units.TILE * 2.0, 0)
	_b(run).apply_map_buff("light_burst")
	near(g.pos.distance_to(run.bear.pos), Units.TILE * 5.0, "empurra 3 celulas", 0.01)
	near(g.stunned, 1.5, "atordoa 1.5s")


# ------------------------------------------------------------- 12. stomp
func test_stomp_pushes_and_stuns_on_landing() -> void:
	var run: GameRun = F.make_full(6)
	var b: BuffSystem = _b(run)
	b.activate_passive("stomp")
	run.bear.pos = Units.cell_center(8, 14)
	var g1: GhostModel = run.ghosts[0]
	g1.pos = run.bear.pos + Vector2(Units.TILE * 1.0, 0)
	var g2: GhostModel = _add_ghost(run, "comum", run.bear.pos + Vector2(0, Units.TILE * 2.0))
	var g3: GhostModel = _add_ghost(run, "comum", run.bear.pos + Vector2(-Units.TILE * 3.0, 0))
	for g in [g1, g2, g3]:
		(g as GhostModel).frozen = 0.0
	var p2: Vector2 = g2.pos
	var p3: Vector2 = g3.pos
	var fired: Array = []
	var cb: Callable = func(id: String) -> void: fired.append(id)
	Events.buff_activated.connect(cb)
	run.jump.active = true
	run.jump.timer = 0.01
	run.update_effects(0.02)
	Events.buff_activated.disconnect(cb)
	near(g1.pos.distance_to(run.bear.pos), Units.TILE * (1.0 + 1.6), "a < 1.6 celulas: empurrado", 0.01)
	near(g1.stunned, 2.0, "a < 2.5 celulas: atordoado 2s")
	eq(g2.pos, p2, "entre 1.6 e 2.5: so atordoa")
	near(g2.stunned, 2.0, "g2 atordoado")
	eq(g3.pos, p3, "fora de 2.5: intocado")
	near(g3.stunned, 0.0, "g3 livre")
	check(fired.has("stomp"), "Events.buff_activated(stomp)")
	# sem o passivo nada acontece
	var r2: GameRun = F.make_full(6)
	r2.bear.pos = Units.cell_center(8, 14)
	r2.ghosts[0].pos = r2.bear.pos + Vector2(Units.TILE, 0)
	r2.jump.active = true
	r2.jump.timer = 0.01
	r2.update_effects(0.02)
	near(r2.ghosts[0].stunned, 0.0, "sem stomp nao atordoa")


# ------------------------------------------------------------- 12. magnet
func test_magnet_pulls_honey_and_orbs() -> void:
	var run: GameRun = F.make_full(7)
	var b: BuffSystem = _b(run)
	run.ghosts[0].frozen = 1000.0
	run.bear.pos = Units.cell_center(8, 14)
	run.honey.drops.append({"pos": run.bear.pos + Vector2(Units.TILE * 3.0, 0), "life": 10.0, "born": 0.0})
	run.honey.drops.append({"pos": run.bear.pos + Vector2(Units.TILE * 5.0, 0), "life": 10.0, "born": 0.0})
	b.collectibles.append({"id": "shield", "type": "map", "icon": "", "rar": "raro",
		"pos": run.bear.pos + Vector2(0, Units.TILE * 3.0), "life": 10.0, "born": 0.0})
	b.update_magnet(0.5)
	check(not b.magnet_pulling, "sem o passivo nao puxa")
	eq((run.honey.drops[0]["pos"] as Vector2).x, run.bear.pos.x + Units.TILE * 3.0, "mel parado sem passivo")
	b.activate_passive("magnet")
	b.update_magnet(0.25)
	check(b.magnet_pulling, "magnet_pulling true ao puxar")
	near((run.honey.drops[0]["pos"] as Vector2).x, run.bear.pos.x + Units.TILE * (3.0 - 1.5), "mel puxado 6 celulas/s", 0.01)
	near((run.honey.drops[1]["pos"] as Vector2).x, run.bear.pos.x + Units.TILE * 5.0, "fora de 4 celulas nao puxa", 0.01)
	near((b.collectibles[0]["pos"] as Vector2).y, run.bear.pos.y + Units.TILE * 1.5, "orbe puxado", 0.01)
	run.honey.drops.remove_at(0)
	b.collectibles.clear()
	b.update_magnet(0.25)
	check(not b.magnet_pulling, "nada no raio => nao puxa")


# ------------------------------------------------------------- 13/14. pool e ritmo de orbes
func test_orb_interval_scales_with_pool() -> void:
	var run: GameRun = F.make_full(1)
	var b: BuffSystem = _b(run)
	b.add_map_to_pool("speed_temp")
	near(b.orb_interval(), 8.0, "1 buff: 8s")
	b.add_map_to_pool("shield")
	near(b.orb_interval(), 8.0 / 1.15, "2 buffs: 8/1.15", 0.0001)
	b.add_map_to_pool("teleport")
	b.add_map_to_pool("freeze_all")
	b.add_map_to_pool("fake_wall")
	near(b.orb_interval(), 8.0 / 1.6, "5 buffs: 8/1.6", 0.0001)
	for id in ["light_burst", "invisible", "slow_time", "light_bomb"]:
		b.add_map_to_pool(id)
	near(b.orb_interval(), 4.0, "minimo 4s")
	b.spawn_timer = 0.0
	run.ghosts[0].frozen = 1000.0
	b.update_collectibles(DT)
	near(b.spawn_timer, 4.0, "timer reiniciado com o intervalo do pool", 0.01)


# ------------------------------------------------------------- 15. mel por fase e bonus de mundo
func test_honey_value_by_phase_and_world_bonus() -> void:
	var old_lang: String = I18n.lang
	I18n.lang = "pt"
	var run: GameRun = F.make_run(4)
	run.ghosts[0].frozen = 1000.0
	for case: Array in [[0, 5], [3, 8], [10, 15], [40, 15]]:
		run.cycle.phases_cleared = int(case[0])
		run.run_honey = 0
		run.honey.drops.clear()
		run.honey.drops.append({"pos": run.bear.pos, "life": 10.0, "born": 0.0})
		run.honey.update(DT)
		eq(run.run_honey, int(case[1]), "pote com %d fases" % int(case[0]))
	# bonus ao concluir o mundo
	var r2: GameRun = F.make_run(4)
	r2.run_honey = 0
	r2.execute_biome_transition()   # phases_cleared = 1
	eq(r2.run_honey, 10, "1 mundo concluido: +10")
	var found: bool = false
	for n: Dictionary in r2.notifications:
		found = found or str(n["text"]) == "Mundo concluído! +10 mel"
	check(found, "notificacao do bonus")
	r2.execute_biome_transition()
	eq(r2.run_honey, 30, "2 mundos: +10 depois +20")
	var r3: GameRun = F.make_run(4)
	r3.cycle.phases_cleared = 14
	r3.run_honey = 0
	r3.execute_biome_transition()
	eq(r3.run_honey, 100, "bonus limitado a 100")
	I18n.lang = "en"
	var r4: GameRun = F.make_run(4)
	r4.execute_biome_transition()
	var en_ok: bool = false
	for n: Dictionary in r4.notifications:
		en_ok = en_ok or str(n["text"]) == "World cleared! +10 honey"
	check(en_ok, "notificacao EN")
	I18n.lang = old_lang


# ------------------------------------------------------------- 10. gelo proporcional a velocidade
func _ice_max(run: GameRun) -> float:
	var m: MechIce = run.mech as MechIce
	run.bear.vel = Vector2.ZERO
	for i in 60:
		m.move_bear(run, DT, Vector2(1, 0))
		run.bear.pos = Units.cell_center(9, 14)
	return run.bear.vel.length()


func test_ice_scales_with_speed() -> void:
	var run: GameRun = F.make_mech_run(2, true)
	var base: float = _ice_max(run)
	near(base, run.bear.speed * 1.65, "max = bear.speed * 1.65", 0.0001)
	var shop: GameRun = F.make_mech_run(2, true)
	shop.attr_levels = {"speed_base": 10}
	shop.recalc_passives()
	near(_ice_max(shop) / base, 1.4, "loja nivel 10 (+40%) escala o gelo", 0.0001)
	var turbo: GameRun = F.make_mech_run(2, true)
	turbo.bear_boost_timer = 4.0
	turbo.bear_boost_mult = 1.8
	near(_ice_max(turbo) / base, 1.8, "turbo escala o gelo", 0.0001)
	var pois: GameRun = F.make_mech_run(2, true)
	pois.bear.poisoned = true
	near(_ice_max(pois) / base, 0.75, "veneno reduz o gelo", 0.0001)
	# aceleracao proporcional: 1o passo
	var acc: GameRun = F.make_mech_run(2, true)
	acc.bear.vel = Vector2.ZERO
	(acc.mech as MechIce).move_bear(acc, DT, Vector2(1, 0))
	near(acc.bear.vel.x, 0.55 * (base / 3.6) * 0.94, "aceleracao = accel * mx/3.6", 0.0001)


# ------------------------------------------------------------- 11. skills removidas
func test_removed_skills_are_gone() -> void:
	for id in ["dash", "swap", "rebound"]:
		check(BuffSystem.buff_def(id).is_empty(), "%s removido de buffs.json" % id)
		for lang in ["pt", "en"]:
			var tbl: Dictionary = (GameState.strings_pt if lang == "pt" else GameState.strings_en)
			check(not (tbl["buffs"] as Dictionary).has(id), "%s sem texto %s" % [id, lang])
	var run: GameRun = F.make_run(1)
	check(not ("rebound_active" in run), "GameRun sem rebound_active")
	check(not GameplayLits.BUFF_FX.has("dash"), "BUFF_FX sem dash")


# ------------------------------------------------------------- 16. VFX novos (ligacao)
func _art_ready(id: String) -> bool:
	if not FileAccess.file_exists("res://assets/vfx/%s/%s_frames.tres" % [id, id]):
		return false
	for f: String in DirAccess.get_files_at("res://assets/vfx/" + id):
		if f.ends_with(".png") and not FileAccess.file_exists("res://assets/vfx/%s/%s.import" % [id, f]):
			return false
	return true


func _vfx_ids(host: Node) -> Array:
	var out: Array = []
	for c: Node in host.get_children():
		if c is VfxPlayer and not c.is_queued_for_deletion():
			out.append((c as VfxPlayer).vfx_id)
	return out


func test_vfx_new_effects_wiring() -> void:
	var run: GameRun = F.make_full(5)
	var host: Node2D = Node2D.new()
	_tree().root.add_child(host)
	var d: VfxDirector = VfxDirector.new()
	d.bind(run, host)
	host.add_child(d)
	d._process(0.0)
	# asset ausente: spawn tolera (retorna null, sem erro)
	check(VfxPlayer.spawn(host, "nao_existe_xyz", {}) == null, "VfxPlayer.spawn tolera asset ausente")
	Events.buff_activated.emit("stomp")
	if _art_ready("stomp"):
		check(_vfx_ids(host).has("stomp"), "stomp one-shot nos pes")
	run.ghosts[0].stunned = 1.0
	run.ghosts[0].boost_timer = 1.0
	d._process(0.0)
	if _art_ready("stun"):
		check(_vfx_ids(host).has("stun"), "loop stun sobre fantasma atordoado")
	if _art_ready("ghost_boost"):
		check(_vfx_ids(host).has("ghost_boost"), "loop ghost_boost sobre fantasma com impulso")
	# histerese do magnet (~0.3s)
	_b(run).magnet_pulling = true
	d._process(0.016)
	near(d._magnet_hold, 0.3, "magnet: segura 0.3s ao puxar")
	_b(run).magnet_pulling = false
	d._process(0.1)
	check(d._magnet_hold > 0.15 and d._magnet_hold < 0.25, "magnet: histerese decai")
	d._process(0.5)
	near(d._magnet_hold, 0.0, "magnet: zera")
	if _art_ready("magnet"):
		_b(run).magnet_pulling = true
		d._process(0.016)
		check(_vfx_ids(host).has("magnet"), "loop magnet no urso")
	host.queue_free()
	await _tree().process_frame


# ------------------------------------------------------------- 17. textos
func test_texts_updated() -> void:
	var old: String = I18n.lang
	var pt: Dictionary = {
		"teleport": "Teleporta para o ponto mais seguro do mapa.",
		"ghost_slow": "A cada 12s: −40% de velocidade nos fantasmas por 4s.",
		"spirit_trap": "A cada 12s: prende o fantasma mais próximo por 4s.",
		"light_burst": "Empurra e atordoa os fantasmas ao redor.",
		"invisible": "Por 5s os fantasmas perdem você de vista e não te pegam.",
		"lightning": "A cada 35s: elimina o fantasma mais próximo.",
		"decoy": "A cada 25s: lança uma isca que atrai os fantasmas.",
		"stomp": "Ao pousar de um pulo, afasta e atordoa fantasmas próximos por 2s.",
		"magnet": "Atrai potes de mel e orbes de poder próximos.",
	}
	I18n.lang = "pt"
	for id: String in pt:
		eq(I18n.buff_desc(id), pt[id], "desc PT " + id)
	eq(I18n.buff_name("stomp"), "Pisão", "nome PT stomp")
	eq(I18n.buff_name("magnet"), "Ímã de Mel", "nome PT magnet")
	check(I18n.t("type_skill_passive").contains("Passivo"), "rotulo Passivo")
	check(I18n.t("howtoTip").contains("fantasmas") and I18n.t("howtoTip").contains("paredes"), "tutorial PT: pulo atravessa paredes e fantasmas")
	I18n.lang = "en"
	eq(I18n.buff_name("stomp"), "Stomp", "nome EN stomp")
	eq(I18n.buff_name("magnet"), "Honey Magnet", "nome EN magnet")
	check(I18n.t("type_skill_passive").contains("Passive"), "rotulo Passive")
	for id: String in pt:
		check(I18n.buff_desc(id) != "" and I18n.buff_desc(id) != pt[id], "desc EN traduzida " + id)
	check(I18n.t("howtoTip").contains("ghosts") and I18n.t("howtoTip").contains("walls"), "tutorial EN")
	I18n.lang = old
	var mjs: String = FileAccess.get_file_as_string("res://tools/extract_legacy_data.mjs")
	check("--force" in mjs and "process.exit" in mjs, "extract_legacy_data exige --force")
