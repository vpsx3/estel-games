extends "res://tests/case.gd"
## Captura / game over e estatisticas da run.

const F: GDScript = preload("res://tests/support/run_factory.gd")


func _put_ghost_on_bear(run: GameRun) -> GhostModel:
	var g: GhostModel = run.ghosts[0]
	g.pos = run.bear.pos
	g.frozen = 1.0   # nao se mover; so testa a captura
	return g


func test_capture_ends_game_with_stats() -> void:
	var run: GameRun = F.make_run(1)
	var got: Array = []
	var cb: Callable = func(s: Dictionary) -> void: got.append(s)
	Events.game_over.connect(cb)
	F.advance(run, 3.5)  # o urso fica parado; o fantasma ainda esta longe
	_put_ghost_on_bear(run)
	run.step(1.0 / 60.0, Vector2.ZERO)
	Events.game_over.disconnect(cb)
	eq(run.state, "lose", "estado lose")
	eq(got.size(), 1, "Events.game_over emitido 1x")
	var st: Dictionary = got[0]
	eq(st["seconds"], 3, "tempo sobrevivido (floor)")
	eq(st["ghosts"], 1, "numero de fantasmas")
	eq(st["biome_reached"], "Floresta Encantada", "bioma (nome PT, como o JS envia)")
	eq(st["biome_index"], 0, "indice")
	var t0: float = run.elapsed
	run.step(0.05, Vector2.ZERO)
	eq(run.elapsed, t0, "apos game over nada avanca")


func test_capture_threshold() -> void:
	var run: GameRun = F.make_run(1)
	var g: GhostModel = _put_ghost_on_bear(run)
	var lim: float = run.bear.size + g.size - Units.px(5.0)
	g.pos = run.bear.pos + Vector2(lim + 0.5, 0)
	run.step(0.0, Vector2.ZERO)
	eq(run.state, "playing", "fora do limiar (size+size-5)")
	g.pos = run.bear.pos + Vector2(lim - 0.5, 0)
	run.step(0.0, Vector2.ZERO)
	eq(run.state, "lose", "dentro do limiar")


func test_invuln_shield_rebound_hide() -> void:
	var run: GameRun = F.make_run(1)
	_put_ghost_on_bear(run)
	run.bear.invuln = 1.0
	run.step(0.0, Vector2.ZERO)
	eq(run.state, "playing", "invulneravel nao morre")
	run.bear.invuln = 0.0
	run.shield_charges = 1
	_put_ghost_on_bear(run).pos += Vector2(1, 0)
	run.step(0.0, Vector2.ZERO)
	eq(run.state, "playing", "escudo absorve")
	eq(run.shield_charges, 0, "carga consumida")
	near(run.bear.invuln, 0.9, "invuln 0.9s do escudo", 0.001)
	check(run.ghosts[0].pos.distance_to(run.bear.pos) > 30.0, "fantasma empurrado ~TILE*1.6")
	run.bear.invuln = 0.0
	run.rebound_active = true
	_put_ghost_on_bear(run).pos += Vector2(1, 0)
	run.step(0.0, Vector2.ZERO)
	eq(run.state, "playing", "rebote absorve")
	check(not run.rebound_active, "rebote consumido")
	near(run.bear.invuln, 1.1, "invuln 1.1s do rebote", 0.001)
	run.bear.invuln = 0.0
	run.cycle.ghost_hide_timer = 0.5
	_put_ghost_on_bear(run)
	run.step(0.0, Vector2.ZERO)
	eq(run.state, "playing", "sem captura durante ghost_hide")


func test_natural_capture_by_chasing() -> void:
	var run: GameRun = F.make_run(8)
	F.advance(run, 60.0)
	eq(run.state, "lose", "fantasma alcanca o urso parado")
	check(int(run.last_stats["seconds"]) < 60, "em menos de 60s")
