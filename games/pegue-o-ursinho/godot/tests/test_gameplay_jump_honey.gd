extends "res://tests/case.gd"
## Pulo (JUMP_DURATION + atributos) e mel (passivo, potes, coleta).

const F: GDScript = preload("res://tests/support/run_factory.gd")


func test_jump_basic_and_cooldown() -> void:
	var j: JumpState = JumpState.new()
	near(j.duration, 0.55, "JUMP_DURATION")
	near(j.cd_max, 10.0, "cd base 10")
	eq(j.try_jump(false, false), "started", "pula")
	check(j.active, "ativo")
	eq(j.try_jump(false, false), "", "sem pulo duplo => ignorado")
	var landed: bool = false
	for i in 40:
		if j.update(1.0 / 60.0):
			landed = true
			break
	check(landed, "pousa em ~0.55s")
	check(not j.active, "inativo")
	near(j.cd, 10.0, "cooldown 10s ao pousar")
	eq(j.try_jump(false, false), "", "em cooldown")
	for i in 601:
		j.update(1.0 / 60.0)
	eq(j.try_jump(false, false), "started", "cooldown acabou")


func test_jump_blocked_frozen_and_choosing() -> void:
	var j: JumpState = JumpState.new()
	eq(j.try_jump(true, false), "", "congelado")
	eq(j.try_jump(false, true), "", "escolha de buff")


func test_jump_attributes() -> void:
	var j: JumpState = JumpState.new()
	j.recalc({"jump_ext": 3, "jump_cd": 10, "double_jump": 1})
	near(j.duration, 0.55 + 0.27, "jump_ext nivel 3 = +0.27s")
	near(j.cd_max, 10.0 * (1.0 - 0.65), "jump_cd nivel 10 = -65%")
	eq(j.max_jumps(), 2, "double_jump")
	eq(j.try_jump(false, false), "started", "1o")
	j.update(0.5)
	eq(j.try_jump(false, false), "double", "2o no ar renova")
	near(j.timer, j.duration, "renova duracao")
	eq(j.try_jump(false, false), "", "3o ignorado")
	j.recalc({})
	near(j.duration, 0.55, "sem atributos: base")


func test_run_jump_event_and_landing_in_wall() -> void:
	var run: GameRun = F.make_run()
	var cnt: Array = [0]
	var cb: Callable = func() -> void: cnt[0] += 1
	Events.bear_jumped.connect(cb)
	check(run.try_jump(), "try_jump ok")
	Events.bear_jumped.disconnect(cb)
	eq(cnt[0], 1, "Events.bear_jumped")
	# pousa dentro de parede => landingTarget na celula livre mais proxima
	run.level.call("set_wall", 12, 14, true)
	run.bear.pos = Units.cell_center(12, 14)
	run.jump.timer = 0.01
	run.update_effects(0.02)
	check(run.bear.landing_target != null, "landingTarget definido")
	for i in 120:
		run.update_effects(1.0 / 60.0)
		if run.bear.landing_target == null:
			break
	check(run.bear.landing_target == null, "deslize terminou")
	check(GridCollision.can_move(run.level, run.bear.pos.x, run.bear.pos.y, run.bear.size), "urso fora da parede")


func test_honey_passive() -> void:
	var run: GameRun = F.make_run()
	run.honey.spawn_timer = 9999.0
	for i in 600:
		run.honey.update_passive(1.0 / 60.0)
	check(run.run_honey >= 9 and run.run_honey <= 10, "HONEY_PASSIVE_RATE=1/s -> ~10 em 10s (%d)" % run.run_honey)


func test_honey_pickup_radius_and_value() -> void:
	var run: GameRun = F.make_run()
	run.honey.spawn_timer = 9999.0
	var r: float = run.bear.size + Units.px(12.0)
	run.honey.drops.append({"pos": run.bear.pos + Vector2(r - 0.5, 0), "life": 14.0, "born": 0.0})
	run.honey.drops.append({"pos": run.bear.pos + Vector2(r + 0.5, 0), "life": 14.0, "born": 0.0})
	run.honey.update(0.0)
	eq(run.run_honey, 5, "HONEY_PICKUP_VALUE=5 so do pote dentro do raio")
	eq(run.honey.drops.size(), 1, "pote fora do raio permanece")


func test_honey_life_spawn_and_cap() -> void:
	var run: GameRun = F.make_run(4)
	run.honey.spawn_timer = 9999.0
	run.honey.drops.append({"pos": Vector2(64, 64), "life": 1.0, "born": 0.0})
	run.honey.update(0.6)
	eq(run.honey.drops.size(), 1, "vivo")
	run.honey.update(0.6)
	eq(run.honey.drops.size(), 0, "expira (HONEY_LIFE)")
	# spawn por intervalo
	run.honey.spawn_timer = 0.01
	run.honey.update(0.02)
	eq(run.honey.drops.size(), 1, "spawn")
	near(run.honey.spawn_timer, 12.0, "HONEY_SPAWN_INTERVAL=12")
	var d: Dictionary = run.honey.drops[0]
	near(float(d["life"]), 14.0, "HONEY_LIFE=14", 0.05)
	check((d["pos"] as Vector2).distance_to(run.bear.pos) >= 3.0 * 32.0, "longe do urso (3 celulas)")
	# limite
	run.honey.drops.clear()
	for i in 3:
		run.honey.drops.append({"pos": Vector2(64 + i * 64, 64), "life": 14.0, "born": 0.0})
	run.honey.spawn_timer = 0.0
	run.honey.update(0.0)
	eq(run.honey.drops.size(), 3, "HONEY_MAX_ON_MAP=3")
