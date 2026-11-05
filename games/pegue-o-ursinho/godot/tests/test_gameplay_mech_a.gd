extends "res://tests/case.gd"
## Mecanicas 1/2: mushroom, tide, ice, lily, bats (numeros de BIOME_MECH via Units).

const F: GDScript = preload("res://tests/support/run_factory.gd")
const DT: float = 1.0 / 60.0


func test_mushroom_procedural_and_launch() -> void:
	var run: GameRun = F.make_mech_run(0, true, 3)
	var m: MechMushroom = run.mech as MechMushroom
	check(m != null, "mecanica mushroom")
	eq(m.mushrooms.size(), 6, "count=6")
	var sp: Vector2i = run.level.call("bear_spawn_cell") as Vector2i
	for e in m.mushrooms:
		var c: Vector2i = e["cell"] as Vector2i
		check(Units.cell_center(c.x, c.y).distance_to(Units.cell_center(sp.x, sp.y)) > Units.TILE * 3.0, "longe do spawn")
		eq(e["dist"], 3, "dist=3")
	m.mushrooms = [{"cell": Vector2i(5, 10), "dist": 3}]
	run.bear.pos = Units.cell_center(5, 10)
	run.bear.facing = "east"
	m.update(run, DT)
	eq(run.bear.landing_target, Units.cell_center(8, 10), "lanca 3 celulas a leste")
	check(run.bear.landing_glide, "glide")
	near(run.bear.mush_cd, 0.4, "cd=0.4")
	run.bear.landing_target = null
	m.update(run, DT)
	eq(run.bear.landing_target, null, "em cooldown nao relanca")


func test_mushroom_stops_before_wall_and_directions() -> void:
	var run: GameRun = F.make_mech_run(0, true, 3)
	var m: MechMushroom = run.mech as MechMushroom
	m.mushrooms = [{"cell": Vector2i(15, 10), "dist": 3}]
	run.bear.pos = Units.cell_center(15, 10)
	run.bear.facing = "east"
	m.update(run, DT)
	eq(run.bear.landing_target, Units.cell_center(16, 10), "para 1 tile antes da parede")
	for d in [["north", Vector2i(15, 7)], ["south", Vector2i(15, 13)], ["west", Vector2i(12, 10)]]:
		run.bear.landing_target = null
		run.bear.mush_cd = 0.0
		run.bear.facing = d[0]
		m.update(run, DT)
		eq(run.bear.landing_target, Units.cell_center((d[1] as Vector2i).x, (d[1] as Vector2i).y), "direcao " + str(d[0]))


func test_mushroom_glide_lands_in_run_loop() -> void:
	var run: GameRun = F.make_mech_run(0, true, 3)
	var m: MechMushroom = run.mech as MechMushroom
	m.mushrooms = [{"cell": Vector2i(5, 10), "dist": 3}]
	run.bear.pos = Units.cell_center(5, 10)
	run.bear.facing = "east"
	run.ghost_sys.ghosts.clear()
	run.ghost_sys.ghosts.append(run.ghost_sys.make_ghost("comum", Units.cell_center(1, 28)))
	run.ghosts[0].frozen = 100.0
	for i in 60:
		run.step(DT, Vector2.ZERO)
	check(run.bear.pos.distance_to(Units.cell_center(8, 10)) < Units.px(6.0), "urso planou ate o destino")
	eq(run.bear.landing_target, null, "pousou")


func test_mushroom_markers_override_procedural() -> void:
	var mk: Node2D = F.marker("mushroom", Vector2i(4, 4), {"dist": 1})
	var run: GameRun = F.make_mech_run(0, true, 3, [mk])
	var m: MechMushroom = run.mech as MechMushroom
	eq(m.mushrooms.size(), 1, "so o colocado a mao")
	eq(m.mushrooms[0]["cell"], Vector2i(4, 4), "celula")
	eq(m.mushrooms[0]["dist"], 1, "dist da instancia")
	mk.free()


func test_tide_levels_and_block() -> void:
	var run: GameRun = F.make_mech_run(1, true)
	var m: MechTide = run.mech as MechTide
	run.elapsed = 0.0
	m.update(run, DT)
	eq(m.flooded_rows.size(), 2, "sin(0)=0 => lvl .5 => floor(.5*5)=2 linhas")
	eq(m.flooded_rows, [28, 27] as Array[int], "linhas mais ao fundo")
	run.elapsed = PI / 2.0 / 0.25
	m.update(run, DT)
	eq(m.flooded_rows.size(), 5, "pico => maxRows=5")
	eq(m.flooded.size(), 5 * 16, "5 linhas x 16 colunas livres")
	check(m.blocks_bear(Units.cell_center(5, 26).x, Units.cell_center(5, 26).y), "alagado bloqueia")
	check(not m.blocks_bear(Units.cell_center(5, 10).x, Units.cell_center(5, 10).y), "seco livre")
	run.elapsed = 3.0 * PI / 2.0 / 0.25
	m.update(run, DT)
	eq(m.flooded_rows.size(), 0, "vale => 0 linhas")


func test_tide_pushes_bear_to_dry() -> void:
	var run: GameRun = F.make_mech_run(1, true)
	var m: MechTide = run.mech as MechTide
	run.elapsed = PI / 2.0 / 0.25
	run.bear.pos = Units.cell_center(5, 28)
	m.update(run, DT)
	check(run.bear.landing_target != null, "empurrao justo")
	check(run.bear.landing_glide, "glide")
	var tc: Vector2i = Units.world_to_cell(run.bear.landing_target as Vector2)
	check(not m.flooded.has(tc), "destino seco")
	eq(tc, Vector2i(5, 23), "celula seca mais proxima")


func test_ice_inertia_clamp_friction() -> void:
	var run: GameRun = F.make_mech_run(2, true)
	var m: MechIce = run.mech as MechIce
	run.bear.pos = Units.cell_center(9, 14)
	var x0: float = run.bear.pos.x
	check(m.move_bear(run, DT, Vector2(1, 0)), "gelo assume o movimento")
	near(run.bear.vel.x, 0.55 * 0.94, "vel = (0 + accel)*friction", 0.0001)
	near(run.bear.pos.x - x0, 0.55 * 0.94 * Units.TILE_SCALE, "deslocamento em px do Godot", 0.0001)
	for i in 40:
		m.move_bear(run, DT, Vector2(0, 0))
		run.bear.pos = Units.cell_center(9, 14)
	check(run.bear.vel.x < 0.517 and run.bear.vel.x > 0.0, "atrito reduz sem input")
	run.bear.vel = Vector2.ZERO
	for i in 30:
		m.move_bear(run, DT, Vector2(1, 0))
		run.bear.pos = Units.cell_center(9, 14)
	near(run.bear.vel.length(), 3.6, "maxSpd=3.6", 0.0001)


func test_ice_bounce_and_phasing() -> void:
	var run: GameRun = F.make_mech_run(2, true)
	var m: MechIce = run.mech as MechIce
	run.bear.pos = Vector2(536.0, Units.cell_center(16, 10).y)
	run.bear.vel = Vector2(3.6, 0.0)
	m.move_bear(run, DT, Vector2.ZERO)
	check(run.bear.vel.x < 0.0, "quica na parede")
	near(run.bear.vel.x, 3.6 * 0.94 * -0.35, "bounce=0.35", 0.0001)
	run.bear.pos = Vector2(536.0, Units.cell_center(16, 10).y)
	run.bear.vel = Vector2(3.6, 0.0)
	run.phase_timer = 1.0
	m.move_bear(run, DT, Vector2.ZERO)
	check(run.bear.vel.x > 0.0, "phasing atravessa (sem quicar)")


func test_ice_integrated_in_step() -> void:
	var run: GameRun = F.make_mech_run(2, true)
	run.ghost_sys.ghosts[0].frozen = 100.0
	run.bear.pos = Units.cell_center(9, 14)
	for i in 30:
		run.step(DT, Vector2(1, 0))
	var x_move: float = run.bear.pos.x
	for i in 30:
		run.step(DT, Vector2.ZERO)
	check(run.bear.pos.x > x_move + 10.0, "continua deslizando sem input")
	run.bear.frozen = 5.0
	run.bear.vel = Vector2(3, 0)
	var xf: float = run.bear.pos.x
	run.step(DT, Vector2(1, 0))
	eq(run.bear.pos.x, xf, "congelado nao desliza")


func test_lily_state_machine() -> void:
	var run: GameRun = F.make_mech_run(3, true, 5)
	var m: MechLily = run.mech as MechLily
	check(m.lilies.size() > 120 and m.lilies.size() < 240, "frac=0.40 de 448 celulas (%d)" % m.lilies.size())
	var cell: Vector2i = Vector2i(5, 10)
	m.lilies = {cell: {"state": "stable", "t": 0.0}}
	run.bear.pos = Units.cell_center(5, 10)
	m.update(run, DT)
	eq(str(m.lilies[cell]["state"]), "sinking", "pisou => afunda")
	near(float(m.lilies[cell]["t"]), 1.1, "sinkDelay=1.1")
	m.update(run, 1.2)
	eq(str(m.lilies[cell]["state"]), "gone", "afundou")
	near(float(m.lilies[cell]["t"]), 3.5, "gone=3.5")
	check(m.blocks_bear(Units.cell_center(5, 10).x, Units.cell_center(5, 10).y), "agua bloqueia")
	check(run.bear.landing_target != null, "urso empurrado para seco")
	var tc: Vector2i = Units.world_to_cell(run.bear.landing_target as Vector2)
	check(tc != cell, "outra celula")
	run.bear.pos = Units.cell_center(tc.x, tc.y)
	m.update(run, 3.6)
	eq(str(m.lilies[cell]["state"]), "stable", "volta apos 3.5s")


func test_lily_hand_markers() -> void:
	var mk: Node2D = F.marker("lilypad", Vector2i(6, 6))
	var run: GameRun = F.make_mech_run(3, true, 5, [mk])
	eq((run.mech as MechLily).lilies.size(), 1, "so a vitoria-regia colocada")
	mk.free()


func test_bats_spawn_hit_freeze_cull() -> void:
	var run: GameRun = F.make_mech_run(4, true, 7)
	var m: MechBats = run.mech as MechBats
	near(m.bat_timer, 3.5, "interval=3.5")
	m.update(run, 3.4)
	eq(m.bats.size(), 0, "ainda nao")
	m.update(run, 0.2)
	eq(m.bats.size(), 1, "spawnou")
	near((m.bats[0]["vel"] as Vector2).length(), Units.speed_px_frame_to_px_s(2.2), "speed 2.2 px/frame via Units", 0.001)
	m.bats.clear()
	run.bear.pos = Units.cell_center(9, 14)
	m.bats.append({"pos": run.bear.pos + Vector2(Units.px(10.0), 0), "vel": Vector2.ZERO, "frame": 0, "ft": 0.0, "hit": false})
	m.update(run, DT)
	near(run.bear.frozen, 2.0, "trava o urso 2s")
	check(bool(m.bats[0]["hit"]), "hit marcado")
	run.bear.frozen = 0.0
	m.update(run, DT)
	near(run.bear.frozen, 0.0, "nao trava de novo")
	check(not run.notifications.is_empty(), "notificacao 'travado'")
	m.bats.clear()
	m.bats.append({"pos": Vector2(-Units.px(41.0), 100.0), "vel": Vector2(-10, 0), "frame": 0, "ft": 0.0, "hit": false})
	m.update(run, DT)
	eq(m.bats.size(), 0, "sai do mapa => removido")


func test_bats_radius_uses_units() -> void:
	var run: GameRun = F.make_mech_run(4, true, 7)
	var m: MechBats = run.mech as MechBats
	m.bats.clear()
	var edge: float = run.bear.size + Units.px(16.0)
	m.bats.append({"pos": run.bear.pos + Vector2(edge + 0.5, 0), "vel": Vector2.ZERO, "frame": 0, "ft": 0.0, "hit": false})
	m.update(run, DT)
	near(run.bear.frozen, 0.0, "fora do raio (size + r*TILE_SCALE)")
	m.bats[0]["pos"] = run.bear.pos + Vector2(edge - 0.5, 0)
	m.update(run, DT)
	near(run.bear.frozen, 2.0, "dentro do raio")
