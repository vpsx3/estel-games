extends "res://tests/case.gd"
## Fantasmas: classes, spawn ponderado, pace, perseguicao reta, errante, veneno, separacao.

const F: GDScript = preload("res://tests/support/run_factory.gd")


func test_first_ghost_and_initial_pace() -> void:
	var run: GameRun = F.make_run()
	eq(run.ghosts.size(), 1, "1 fantasma inicial")
	eq(run.ghosts[0].tipo, "comum", "1o e comum")
	# diff = ghostSpeed(0.75) * INITIAL_PACE(0.5) * (1 + 0.1 * 0)
	near(run.ghosts[0].speed, 1.7 * 0.75 * 0.5, "velocidade inicial legada")
	near(run.ghost_sys.diff_mult(), 0.375, "diff_mult")
	run.cycle.cycle_count = 1
	run.cycle.phases_cleared = 10
	near(run.ghost_sys.diff_mult(), (0.75 + 0.10) * 0.5 * (1.0 + 0.10 * 10.0), "diff_mult c/ ciclo e fases")


func test_class_stats_px() -> void:
	var run: GameRun = F.make_run()
	for tipo: String in ["comum", "rapido", "pesado", "errante", "venenoso"]:
		var g: GhostModel = run.ghost_sys.make_ghost(tipo, Vector2(100, 100))
		near(g.size, Units.px(float(GameState.ghost_types[tipo]["size"])), "size px " + tipo)
		near(g.base_class_speed, float(GameState.ghost_types[tipo]["speed"]), "speed legada " + tipo)


func test_weighted_spawn_distribution() -> void:
	var run: GameRun = F.make_run(42)
	var counts: Dictionary = {"comum": 0, "rapido": 0, "pesado": 0, "errante": 0, "venenoso": 0}
	var n: int = 20000
	for i in n:
		counts[run.ghost_sys.weighted_random()] += 1
	var w: Dictionary = {"comum": 50.0, "rapido": 15.0, "pesado": 15.0, "errante": 12.0, "venenoso": 8.0}
	for k: String in w:
		near(float(counts[k]) / n, w[k] / 100.0, "freq " + k, 0.015)


func test_spawn_min_dist_and_determinism() -> void:
	var a: GameRun = F.make_run(7)
	var b: GameRun = F.make_run(7)
	for i in 12:
		a.ghost_sys.spawn_ghost()
		b.ghost_sys.spawn_ghost()
	for i in a.ghosts.size():
		eq(a.ghosts[i].pos, b.ghosts[i].pos, "determinismo pos %d" % i)
		eq(a.ghosts[i].tipo, b.ghosts[i].tipo, "determinismo tipo %d" % i)
		if i >= 1:
			var md: float = float(GameState.ghost_types[a.ghosts[i].tipo]["minDist"]) * 32.0
			check(a.ghosts[i].pos.distance_to(a.bear.pos) > md - 0.001, "minDist respeitada #%d" % i)


func test_spawn_by_rate() -> void:
	var run: GameRun = F.make_run(3)
	F.advance(run, 19.9, Vector2.ZERO, true)
	eq(run.ghosts.size(), 1, "antes de ghostSpawnRate (20s)")
	F.advance(run, 0.3, Vector2.ZERO, true)
	eq(run.ghosts.size(), 2, "spawn aos 20s")
	near(run.next_ghost_time, 40.0, "proximo spawn +20s", 0.05)


func test_straight_chase_ignores_walls() -> void:
	var run: GameRun = F.make_run()
	run.bear.pos = Vector2(100, 100)
	var g: GhostModel = run.ghosts[0]
	g.pos = Vector2(100, 400)
	var s: float = Units.speed_px_frame_to_px_s(g.speed)
	for i in 60:
		run.ghost_sys.move_ghosts(1.0 / 60.0)
	near(g.pos.y, 400.0 - s, "1s em linha reta ate o urso", 0.01)
	near(g.pos.x, 100.0, "sem desvio lateral", 0.01)
	eq(g.facing, "north", "facing")


func test_decoy_and_slow_hooks() -> void:
	var run: GameRun = F.make_run()
	run.bear.pos = Vector2(100, 100)
	var g: GhostModel = run.ghosts[0]
	g.pos = Vector2(300, 300)
	run.decoy = {"pos": Vector2(300, 100), "life": 5.0, "max_life": 6.0}
	run.ghost_slow_timer = 5.0
	run.ghost_slow_mult = 0.5
	var s: float = Units.speed_px_frame_to_px_s(g.speed) * 0.5
	for i in 30:
		run.ghost_sys.move_ghosts(1.0 / 60.0)
	near(g.pos.y, 300.0 - s * 0.5, "decoy atrai + ghost_slow 0.5", 0.01)
	near(g.pos.x, 300.0, "x inalterado", 0.01)


func test_frozen_trapped_invisible_hide() -> void:
	var run: GameRun = F.make_run()
	var g: GhostModel = run.ghosts[0]
	g.pos = Vector2(300, 300)
	g.frozen = 1.0
	run.ghost_sys.move_ghosts(0.1)
	eq(g.pos, Vector2(300, 300), "frozen parado")
	g.frozen = 0.0
	g.trapped = 1.0
	run.ghost_sys.move_ghosts(0.1)
	eq(g.pos, Vector2(300, 300), "trapped parado")
	g.trapped = 0.0
	run.invisible_timer = 1.0
	run.ghost_sys.move_ghosts(0.1)
	eq(g.pos, Vector2(300, 300), "bear invisivel => parados")
	run.invisible_timer = 0.0
	run.cycle.ghost_hide_timer = 0.5
	run.ghost_sys.move_ghosts(0.1)
	eq(g.pos, Vector2(300, 300), "hide timer => parados")


func test_errante_modes() -> void:
	var run: GameRun = F.make_run(5)
	var g: GhostModel = run.ghost_sys.make_ghost("errante", Vector2(300, 300))
	run.ghosts.append(g)
	check(not g.is_chasing, "errante comeca vagando")
	check(g.mode_timer >= 4000.0 and g.mode_timer < 8000.0, "modeTimer 4000..8000 ms")
	g.mode_timer = 10.0
	run.ghost_sys.move_ghosts(0.02)
	check(g.is_chasing, "alterna para perseguir")
	check(g.mode_timer >= 4000.0 and g.mode_timer < 8000.0, "novo modeTimer")
	var w: GhostModel = run.ghost_sys.make_ghost("errante", Vector2(300, 300))
	run.ghosts.append(w)
	for i in 600:
		run.ghost_sys.wander_move(w, 1.0 / 60.0, 1.0)
		check(GridCollision.can_move(run.level, w.pos.x, w.pos.y, w.size), "wander fora de parede")


func test_poison() -> void:
	var run: GameRun = F.make_run()
	run.ghosts.clear()
	var g: GhostModel = run.ghost_sys.make_ghost("venenoso", run.bear.pos + Vector2(Units.px(80) - 5.0, 0))
	run.ghosts.append(g)
	run.ghost_sys.move_ghosts(1.0 / 60.0)
	check(run.bear.poisoned, "envenena dentro de POISON_RADIUS")
	near(run.bear.poison_left, 2.0, "POISON_DURATION 2000ms")
	near(g.poison_timer, 1000.0, "POISON_COOLDOWN 1000ms")
	run.bear.poisoned = false
	run.ghost_sys.move_ghosts(1.0 / 60.0)
	check(not run.bear.poisoned, "cooldown impede")
	var g2: GhostModel = run.ghost_sys.make_ghost("venenoso", run.bear.pos + Vector2(Units.px(80) + 20.0, 0))
	run.ghosts.clear()
	run.ghosts.append(g2)
	run.ghost_sys.move_ghosts(0.0)
	check(not run.bear.poisoned, "fora do raio nao envenena")
	run.bear.poisoned = true
	run.bear.poison_left = 2.0
	for i in 121:
		run.update_effects(1.0 / 60.0)
	check(not run.bear.poisoned, "veneno expira em 2s")


func test_separation() -> void:
	var run: GameRun = F.make_run()
	run.ghosts.clear()
	var a: GhostModel = run.ghost_sys.make_ghost("pesado", Vector2(300, 300))
	var b: GhostModel = run.ghost_sys.make_ghost("comum", Vector2(305, 300))
	run.ghosts.append(a)
	run.ghosts.append(b)
	run.ghost_sys.resolve_collisions()
	near(a.pos.distance_to(b.pos), a.size + b.size, "separados pela soma dos raios", 0.01)
	b.pos = a.pos
	run.ghost_sys.resolve_collisions()
	near(b.pos.x - a.pos.x, (a.size + b.size) * 0.5, "d==0 desloca b em minDist/2", 0.01)
