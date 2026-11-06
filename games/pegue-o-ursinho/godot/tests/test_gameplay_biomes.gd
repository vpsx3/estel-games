extends "res://tests/case.gd"
## Ciclo de biomes: duracao, aviso, anuncio, transicao, volta ao bioma 1 com escalada de ciclo.

const F: GDScript = preload("res://tests/support/run_factory.gd")


func test_effective_values() -> void:
	near(BiomeCycle.effective_speed(0.75, 0), 0.75, "ciclo 0 velocidade")
	near(BiomeCycle.effective_speed(0.75, 2), 0.95, "ciclo 2: +0.10/ciclo")
	near(BiomeCycle.effective_spawn_rate(20.0, 0), 20.0, "ciclo 0 taxa")
	near(BiomeCycle.effective_spawn_rate(20.0, 3), 14.0, "ciclo 3: -2s/ciclo")
	near(BiomeCycle.effective_spawn_rate(14.0, 10), 5.0, "minimo 5s")


func test_warning_and_transition_timing() -> void:
	var run: GameRun = F.make_run(11)
	var warned_at: float = -1.0
	var changed_at: float = -1.0
	var guard: int = 0
	while changed_at < 0.0 and guard < 4000:
		run.bear.invuln = 100.0
		run.step(0.05, Vector2.ZERO)
		if warned_at < 0.0 and run.cycle.phase == "warning":
			warned_at = run.elapsed
		if run.cycle.current_biome == 1:
			changed_at = run.elapsed
		guard += 1
	near(warned_at, 35.0, "aviso aos 35s (BIOME_DURATION-WARNING)", 0.06)
	near(changed_at, 45.0, "troca aos 45s (BIOME_DURATION)", 0.06)
	eq(run.cycle.phases_cleared, 1, "phasesCleared 1")
	eq(run.cycle.phase, "playing", "retomou (sem handler)")
	near(run.cycle.start_time, changed_at, "biomeStartTime = elapsed", 0.001)
	check(run.cycle.announce_timer > 2.9 and run.cycle.announce_timer <= 3.0, "anuncio BIOME_ANNOUNCE_DURATION=3")
	check(run.cycle.ghost_hide_timer > 0.0 and run.cycle.ghost_hide_timer <= 0.5, "fantasmas ocultos 0.5s")
	check(run.bear.invuln >= 1.0, "invulneravel na transicao")
	eq(run.level.config.index, 1, "nivel trocado pelo loader")


func test_transition_repositions_and_rescales() -> void:
	var run: GameRun = F.make_run(2)
	run.ghost_sys.spawn_ghost()
	run.execute_biome_transition()
	var sp: Vector2i = run.level.call("bear_spawn_cell")
	eq(run.bear.pos, Units.cell_center(sp.x, sp.y), "urso no spawn do novo bioma")
	for g in run.ghosts:
		check(g.pos.distance_to(run.bear.pos) > Units.TILE * 10.0 - 0.001, "fantasma a >10 celulas do urso")
		# bioma 2: ghostSpeed 0.8; 1 fase concluida
		near(g.speed, g.base_class_speed * 0.8 * 0.5 * 1.1, "re-escala por fase")
	near(run.next_ghost_time, run.elapsed + 18.0 + 0.0 * 0, "proximo spawn: taxa do bioma 2 (18s)")


func test_transition_spawns_ghost_if_none() -> void:
	var run: GameRun = F.make_run(2)
	run.ghosts.clear()
	run.execute_biome_transition()
	eq(run.ghosts.size(), 1, "garante 1 fantasma")


func test_choosing_pauses_and_resume_announces() -> void:
	var run: GameRun = F.make_run(2)
	var holder: Array = []
	run.world_choice_handler = func() -> void: holder.append(true)
	run.execute_biome_transition()
	eq(run.cycle.phase, "choosing", "aguardando escolha")
	var e0: float = run.elapsed
	run.step(0.05, Vector2.RIGHT)
	eq(run.elapsed, e0, "pausa real: elapsed nao avanca")
	eq(holder.size(), 1, "handler chamado")
	check(not run.try_jump(), "sem pulo durante a escolha")
	run.resume_after_choice()
	near(run.cycle.announce_timer, 3.0, "anuncio so apos a escolha")
	eq(run.cycle.phase, "playing", "playing")


func test_full_cycle_wraps_and_escalates() -> void:
	var run: GameRun = F.make_run(9)
	for i in 10:
		run.execute_biome_transition()
	eq(run.cycle.current_biome, 0, "volta ao bioma 1")
	eq(run.cycle.cycle_count, 1, "cycleCount 1")
	eq(run.cycle.phases_cleared, 10, "phasesCleared 10")
	near(run.biome_effective_speed(), 0.75 + 0.10, "bioma 1 ciclo 2: velocidade +0.10")
	near(run.biome_effective_spawn_rate(), 18.0, "bioma 1 ciclo 2: taxa 18s")
	var g: GhostModel = run.ghosts[0]
	near(g.speed, g.base_class_speed * 0.85 * 0.5 * 2.0, "pace com 10 fases e ciclo 1")


func test_biome_events() -> void:
	var seen: Array = []
	var cb: Callable = func(i: int) -> void: seen.append(i)
	Events.biome_changed.connect(cb)
	var run: GameRun = F.make_run(1)
	run.execute_biome_transition()
	Events.biome_changed.disconnect(cb)
	eq(seen, [1], "Events.biome_changed(1)")


func test_syncs_game_state() -> void:
	var run: GameRun = F.make_run(1)
	run.sync_game_state = true
	run.execute_biome_transition()
	eq(GameState.current_biome, 1, "GameState.current_biome")
	eq(GameState.phases_cleared, 1, "GameState.phases_cleared")
	GameState.reset_run()
