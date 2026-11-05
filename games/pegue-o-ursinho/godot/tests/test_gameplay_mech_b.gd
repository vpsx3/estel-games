extends "res://tests/case.gd"
## Mecanicas 2/2: windows, castle, sky, fire, void.

const F: GDScript = preload("res://tests/support/run_factory.gd")
const DT: float = 1.0 / 60.0


func _first_interior_wall(run: GameRun) -> Vector2i:
	for r in range(2, 28):
		for c in range(2, 16):
			if bool(run.level.call("is_wall", c, r)):
				return Vector2i(c, r)
	return Vector2i(-1, -1)


func test_windows_procedural_on_walls() -> void:
	var run: GameRun = F.make_mech_run(5, false, 4)
	var m: MechWindows = run.mech as MechWindows
	check(m.windows.size() > 5, "frac=0.12 das paredes internas (%d)" % m.windows.size())
	for w in m.windows:
		var c: Vector2i = w["cell"] as Vector2i
		check(bool(run.level.call("is_wall", c.x, c.y)), "janela em parede")
		eq(w["radius"], 3.0, "radius 3 celulas")
		eq(w["telegraph"], 1.2, "telegraph")
		eq(w["cd_max"], 12.0, "cd")


func test_windows_telegraph_spawn_and_cooldown() -> void:
	var run: GameRun = F.make_mech_run(5, false, 4)
	var m: MechWindows = run.mech as MechWindows
	var cell: Vector2i = _first_interior_wall(run)
	m.windows = [{"cell": cell, "armed": false, "t": 0.0, "cd": 0.0, "radius": 3.0, "telegraph": 1.2, "cd_max": 12.0}]
	run.bear.pos = Units.cell_center(cell.x, cell.y) + Vector2(Units.TILE * 2.0, 0)
	var n0: int = run.ghosts.size()
	m.update(run, 1.0)
	check(bool(m.windows[0]["armed"]), "armada")
	eq(run.ghosts.size(), n0, "ainda telegrafando")
	m.update(run, 0.3)
	eq(run.ghosts.size(), n0 + 1, "fantasma saiu da janela")
	eq(run.ghosts[n0].tipo, "comum", "comum")
	eq(run.ghosts[n0].pos, Units.cell_center(cell.x, cell.y), "na janela")
	near(float(m.windows[0]["cd"]), 12.0, "cd 12s")
	m.update(run, 5.0)
	eq(run.ghosts.size(), n0 + 1, "em cooldown")
	# fora do raio: t decai
	m.windows = [{"cell": cell, "armed": false, "t": 0.5, "cd": 0.0, "radius": 3.0, "telegraph": 1.2, "cd_max": 12.0}]
	run.bear.pos = Units.cell_center(cell.x, cell.y) + Vector2(Units.TILE * 4.0, 0)
	m.update(run, 0.2)
	near(float(m.windows[0]["t"]), 0.3, "decai fora do raio")
	check(not bool(m.windows[0]["armed"]), "desarmada")


func test_windows_markers() -> void:
	var run0: GameRun = F.make_mech_run(5, false, 4)
	var cell: Vector2i = _first_interior_wall(run0)
	var mk: Node2D = F.marker("window", cell, {"telegraph": 0.5})
	var run: GameRun = F.make_mech_run(5, false, 4, [mk])
	var m: MechWindows = run.mech as MechWindows
	eq(m.windows.size(), 1, "so a colocada")
	eq(m.windows[0]["telegraph"], 0.5, "telegraph da instancia")
	eq(m.windows[0]["radius"], 3.0, "radius da config")
	mk.free()


func test_castle_gates_and_carpet() -> void:
	var run: GameRun = F.make_mech_run(6, false, 6)
	var m: MechCastle = run.mech as MechCastle
	check(m.gates.size() > 0, "ha grades em corredores (%d)" % m.gates.size())
	for g in m.gates:
		var c: Vector2i = g["cell"] as Vector2i
		check(not bool(run.level.call("is_wall", c.x, c.y)), "grade em celula livre")
		var h: bool = bool(run.level.call("is_wall", c.x, c.y - 1)) and bool(run.level.call("is_wall", c.x, c.y + 1))
		var v: bool = bool(run.level.call("is_wall", c.x - 1, c.y)) and bool(run.level.call("is_wall", c.x + 1, c.y))
		check(h or v, "corredor")
	var rows: Dictionary = {}
	for cell: Vector2i in m.carpet:
		rows[cell.y] = true
	eq(rows.size(), 3, "carpetRows=3")
	var any: Vector2i = m.carpet.keys()[0] as Vector2i
	run.bear.pos = Units.cell_center(any.x, any.y)
	near(m.speed_mult(run), 1.5, "carpetBoost 1.5")
	run.bear.pos = Units.cell_center(1, 1) if not m.carpet.has(Vector2i(1, 1)) else Units.cell_center(2, 2)
	if not m.carpet.has(Units.world_to_cell(run.bear.pos)):
		near(m.speed_mult(run), 1.0, "fora do tapete 1.0")


func test_castle_gate_closing_and_fairness() -> void:
	var run: GameRun = F.make_mech_run(6, true, 6)
	var m: MechCastle = run.mech as MechCastle
	m.gates = [{"cell": Vector2i(5, 10), "phase": 0.0, "cl": -1.0}]
	var pos: Vector2 = Units.cell_center(5, 10)
	check(not m.blocks_bear(pos.x, pos.y), "cl=-1 inicial aberta")
	run.elapsed = PI / 2.0 / 1.1
	run.bear.pos = Units.cell_center(1, 1)
	m.update(run, DT)
	near(float(m.gates[0]["cl"]), 1.0, "sin(...)=1", 0.0001)
	check(m.blocks_bear(pos.x, pos.y), "cl > 0.4 bloqueia")
	run.bear.pos = pos
	m.update(run, DT)
	near(float(m.gates[0]["cl"]), -1.0, "grade ocupada nao fecha")
	check(not m.blocks_bear(pos.x, pos.y), "aberta sob o urso")
	run.elapsed = 0.2   # sin(0.22)=0.218 < 0.4
	run.bear.pos = Units.cell_center(1, 1)
	m.update(run, DT)
	check(not m.blocks_bear(pos.x, pos.y), "cl 0.218 < 0.4 ainda passa")


func test_castle_markers() -> void:
	var gate: Node2D = F.marker("gate", Vector2i(5, 5), {"phase": 1.0})
	var carpet: Node2D = F.marker("carpet", Vector2i(3, 8), {"length_cells": 4})
	var run: GameRun = F.make_mech_run(6, true, 6, [gate, carpet])
	var m: MechCastle = run.mech as MechCastle
	eq(m.gates.size(), 1, "1 grade colocada")
	eq(m.carpet.size(), 4, "tapete de 4 celulas")
	check(m.carpet.has(Vector2i(6, 8)), "estende para a direita")
	gate.free()
	carpet.free()
	# so grade colocada: tapete continua procedural
	var gate2: Node2D = F.marker("gate", Vector2i(5, 5))
	var run2: GameRun = F.make_mech_run(6, true, 6, [gate2])
	check((run2.mech as MechCastle).carpet.size() > 0, "tapete procedural quando nao ha marcador de tapete")
	gate2.free()


func test_sky_platforms_winds_and_blocking() -> void:
	var run: GameRun = F.make_mech_run(7, true, 8)
	var m: MechSky = run.mech as MechSky
	check(m.platforms.size() >= 1 and m.platforms.size() <= 5, "ate 5 plataformas (%d)" % m.platforms.size())
	for i in m.platforms.size():
		for j in range(i + 1, m.platforms.size()):
			var a: Dictionary = m.platforms[i]
			var b: Dictionary = m.platforms[j]
			check(absi(int(a["r0"]) - int(b["r0"])) + absi(int(a["c0"]) - int(b["c0"])) >= 3, "espacadas")
	check(m.winds.size() > 0, "correntes de ar")
	m.platforms = [{"r0": 10, "c0": 5, "axis": "h", "phase": 0.0, "range": 2, "off": 0, "cont": 0.0, "r": 10, "c": 5}]
	run.elapsed = PI / 2.0 / 0.4
	run.bear.pos = Units.cell_center(1, 1)
	m.update(run, DT)
	eq(m.platforms[0]["c"], 7, "desliza +2 (platRange)")
	near(float(m.platforms[0]["cont"]), 2.0, "contínuo")
	var p: Vector2 = Units.cell_center(7, 10)
	check(m.blocks_bear(p.x, p.y), "plataforma bloqueia")
	run.bear.pos = p
	m.update(run, DT)
	check(run.bear.landing_target != null and run.bear.landing_glide, "plataforma empurra o urso")
	check(Units.world_to_cell(run.bear.landing_target as Vector2) != Vector2i(7, 10), "para outra celula")


func test_sky_wind_drift() -> void:
	var run: GameRun = F.make_mech_run(7, true, 8)
	var m: MechSky = run.mech as MechSky
	m.platforms.clear()
	m.winds = {Vector2i(5, 10): Vector2(1, 0)}
	run.bear.pos = Units.cell_center(5, 10)
	var x0: float = run.bear.pos.x
	m.apply_drift(run, DT)
	near(run.bear.pos.x - x0, 1.4 * Units.TILE_SCALE, "windForce 1.4 px/frame -> Units", 0.0001)
	run.bear.pos = Units.cell_center(6, 10)
	x0 = run.bear.pos.x
	m.apply_drift(run, DT)
	eq(run.bear.pos.x, x0, "sem corrente fora da faixa")
	# a deriva atua depois do movimento (so quando o urso se move, como no JS)
	run.bear.pos = Units.cell_center(5, 10)
	run.ghost_sys.ghosts[0].frozen = 100.0
	run.mech = m
	var xs: float = run.bear.pos.x
	run.step(DT, Vector2(0, 1))
	check(run.bear.pos.x > xs, "empurrado pelo vento ao andar")


func test_sky_markers() -> void:
	var plat: Node2D = F.marker("platform", Vector2i(8, 8), {"axis": "v", "range_cells": 1, "phase": 0.0})
	var wind: Node2D = F.marker("wind", Vector2i(2, 3), {"length_cells": 3, "wind_dir": Vector2i(0, 1)})
	var run: GameRun = F.make_mech_run(7, true, 8, [plat, wind])
	var m: MechSky = run.mech as MechSky
	eq(m.platforms.size(), 1, "1 plataforma colocada")
	eq(m.platforms[0]["range"], 1, "range da instancia")
	eq(m.winds.size(), 3, "3 celulas de vento")
	eq(m.winds[Vector2i(2, 5)], Vector2(0, 1), "direcao")
	plat.free()
	wind.free()


func test_fire_geysers_state_push_invuln() -> void:
	var run: GameRun = F.make_mech_run(8, true, 9)
	var m: MechFire = run.mech as MechFire
	eq(m.geysers.size(), 10, "geyserCount=10")
	var sp: Vector2i = run.level.call("bear_spawn_cell") as Vector2i
	for g in m.geysers:
		var c: Vector2i = g["cell"] as Vector2i
		check(absi(c.y - sp.y) + absi(c.x - sp.x) > 2, "longe do spawn")
	var cell: Vector2i = Vector2i(6, 12)
	m.geysers = [{"cell": cell, "phase": PI / 2.0}]
	run.elapsed = 0.0
	eq(m.geyser_state(m.geysers[0]), "fire", "sin=1 > 0.6")
	m.geysers[0]["phase"] = asin(0.45)
	eq(m.geyser_state(m.geysers[0]), "warming", "0.3 < 0.45 <= 0.6")
	m.geysers[0]["phase"] = asin(0.1)
	eq(m.geyser_state(m.geysers[0]), "idle", "idle")
	m.geysers[0]["phase"] = PI / 2.0
	run.bear.pos = Units.cell_center(cell.x, cell.y)
	run.bear.invuln = 0.0
	m.update(run, DT)
	check(run.bear.landing_target != null and run.bear.landing_glide, "empurra para fora")
	check(run.bear.invuln >= 0.4 - 0.0001, "invuln 0.4")
	m.geysers[0]["phase"] = asin(0.1)
	run.bear.landing_target = null
	run.bear.invuln = 0.0
	m.update(run, DT)
	check(run.bear.landing_target == null and run.bear.invuln == 0.0, "idle nao empurra")


func test_fire_trail_pushes_and_stuns_ghosts() -> void:
	var run: GameRun = F.make_mech_run(8, true, 9)
	var m: MechFire = run.mech as MechFire
	m.geysers.clear()
	run.bear.moving = true
	run.bear.pos = Units.cell_center(9, 14)
	m.update(run, DT)
	eq(m.trail.size(), 1, "gota de rastro")
	near(float(m.trail[0]["life"]), 1.4 - DT, "trailLife=1.4", 0.001)
	m.update(run, 0.05)
	eq(m.trail.size(), 1, "trailDrop=0.12 ainda nao")
	m.update(run, 0.1)
	eq(m.trail.size(), 2, "2a gota")
	var g: GhostModel = run.ghosts[0]
	g.pos = Units.cell_center(9, 14) + Vector2(Units.TILE * 0.3, 0)
	var before: float = g.pos.distance_to(run.bear.pos)
	m.update(run, DT)
	check(g.pos.distance_to(run.bear.pos) > before, "fantasma empurrado")
	near(g.frozen, 0.6, "trailFreeze=0.6")
	run.bear.moving = false
	m.update(run, 2.0)
	eq(m.trail.size(), 0, "rastro expira")


func test_void_cycle_phase_blind_and_alpha() -> void:
	var run: GameRun = F.make_mech_run(9, true, 10)
	var m: MechVoid = run.mech as MechVoid
	eq(m.portals.size(), 2, "portals=2")
	near(m.invert_timer, 5.0, "invertPeriod - invertDur")
	eq(m.invert_mode, "normal", "comeca normal")
	run.ghost_sys.ghosts[0].frozen = 100.0
	m.update(run, 5.01)
	eq(m.invert_mode, "phase", "1o especial = phase")
	near(m.flash, 0.3, "flash")
	check(run.phase_timer >= 0.2 - 0.0001, "phase reusa phase_timer")
	check(run.is_phasing(), "atravessa paredes")
	near(m.ghost_alpha(), 1.0, "fantasmas visiveis em phase")
	m.update(run, 3.01)
	eq(m.invert_mode, "normal", "volta ao normal")
	m.update(run, 5.01)
	eq(m.invert_mode, "blind", "2o especial = blind")
	near(m.ghost_alpha(), 0.15, "fantasmas a 15%")
	m.update(run, 3.01)
	eq(m.invert_mode, "normal", "normal")
	m.update(run, 5.01)
	eq(m.invert_mode, "phase", "alterna de volta para phase")


func test_void_portal_teleport_and_cooldown() -> void:
	var run: GameRun = F.make_mech_run(9, true, 10)
	var m: MechVoid = run.mech as MechVoid
	m.portals = [Vector2i(5, 10)]
	run.bear.pos = Units.cell_center(5, 10)
	run.bear.landing_target = Vector2.ONE
	var from: Vector2 = run.bear.pos
	m.update(run, DT)
	check(run.bear.pos.distance_to(from) > Units.TILE * 8.0, "teleporta a > 8 celulas")
	eq(run.bear.landing_target, null, "limpa landingTarget")
	near(m.portal_cd, 2.0, "portalCd=2")
	run.bear.pos = Units.cell_center(5, 10)
	var again: Vector2 = run.bear.pos
	m.update(run, DT)
	eq(run.bear.pos, again, "em cooldown")
	m.update(run, 2.1)
	check(run.bear.pos.distance_to(again) > 0.0, "libera depois do cd")


func test_void_portal_markers() -> void:
	var p1: Node2D = F.marker("portal", Vector2i(3, 3))
	var p2: Node2D = F.marker("portal", Vector2i(12, 20))
	var run: GameRun = F.make_mech_run(9, true, 10, [p1, p2])
	eq((run.mech as MechVoid).portals, [Vector2i(3, 3), Vector2i(12, 20)] as Array[Vector2i], "portais a mao")
	p1.free()
	p2.free()
