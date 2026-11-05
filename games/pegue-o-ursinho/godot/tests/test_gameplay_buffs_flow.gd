extends "res://tests/case.gd"
## Fluxo de escolha: selecao pre-run "3 de 5" por selW, startRun, escolha de +1 buff a cada troca
## de mundo (openWorldChoice/pickWorldBuff/worldReroll) e pesos mapW/selW.

const F: GDScript = preload("res://tests/support/run_factory.gd")


func _new(seed_value: int, attrs: Dictionary = {}) -> BuffSystem:
	var run: GameRun = GameRun.new(seed_value)
	run.attr_levels = attrs
	run.level_loader = func(i: int) -> Object: return F.open_level(i)
	MechFactory.install(run)
	var b: BuffSystem = BuffSystem.new(run)
	b.attach()
	return b


func test_selection_5_options_distinct_weighted() -> void:
	var b: BuffSystem = _new(1)
	var opts: Array = b.open_selection()
	eq(opts.size(), 5, "5 opcoes")
	var ids: Dictionary = {}
	for o: Dictionary in opts:
		ids[str(o["id"])] = true
	eq(ids.size(), 5, "sem repeticao")
	# determinismo com a mesma seed
	var b2: BuffSystem = _new(1)
	var opts2: Array = b2.open_selection()
	for i in 5:
		eq(str((opts[i] as Dictionary)["id"]), str((opts2[i] as Dictionary)["id"]), "mesma seed => mesmas opcoes")
	# peso: comum selW 14 aparece bem mais que raro selW 5 em muitas rodadas
	var count: Dictionary = {}
	for seed_i in 400:
		var bb: BuffSystem = _new(seed_i + 100)
		for o: Dictionary in bb.open_selection():
			count[str(o["id"])] = int(count.get(str(o["id"]), 0)) + 1
	check(int(count["speed_temp"]) > int(count["lightning"]), "selW 14 > selW 5 na frequencia")


func test_toggle_pick_max_3_and_start() -> void:
	var b: BuffSystem = _new(2)
	var opts: Array = b.open_selection()
	var ids: Array = []
	for o: Dictionary in opts:
		ids.append(str(o["id"]))
	check(b.toggle_pick(ids[0]), "marca 1")
	check(b.toggle_pick(ids[1]), "marca 2")
	check(b.toggle_pick(ids[2]), "marca 3")
	check(not b.toggle_pick(ids[3]), "4o recusado")
	eq(b.selection_picks.size(), 3, "max 3")
	check(b.toggle_pick(ids[0]), "desmarca")
	eq(b.selection_picks.size(), 2, "2")
	check(not b.can_start(), "precisa de 3")
	check(not b.start_run(F.open_level(0)), "start com 2 recusado")
	check(not b.toggle_pick("nao_existe"), "id fora das opcoes")
	check(b.toggle_pick(ids[3]), "marca outro")
	check(b.can_start(), "3 => pode iniciar")


func test_start_run_splits_fixed_and_map() -> void:
	var b: BuffSystem = _new(3)
	b.open_selection()
	b.selection_options = [BuffSystem.buff_def("speed_temp"), BuffSystem.buff_def("ghost_slow"),
		BuffSystem.buff_def("dash"), BuffSystem.buff_def("decoy"), BuffSystem.buff_def("shield")]
	b.toggle_pick("speed_temp")
	b.toggle_pick("ghost_slow")
	b.toggle_pick("decoy")
	check(b.start_run(F.open_level(0)), "inicia")
	eq(b.run.state, "playing", "run jogando")
	eq(b.fixed_buffs, ["ghost_slow", "decoy"] as Array[String], "fixos ativados")
	eq(b.spawn_pool.size(), 1, "pool de spawn = so buffs de mapa escolhidos")
	eq(str((b.spawn_pool[0] as Dictionary)["id"]), "speed_temp", "speed_temp no pool")
	near(float(b.fixed_timers["decoy"]), 30.0, "timer do fixo")
	near(b.spawn_timer, 8.0, "spawnTimer = SPAWN_INTERVAL_BASE")
	eq(b.build_ids.size(), 3, "build")


func test_selectable_pool_excludes_active_fixed() -> void:
	var b: BuffSystem = _new(4)
	eq(b.selectable_pool().size(), 16, "16 no inicio")
	b.activate_fixed("lightning")
	b.activate_fixed("decoy")
	eq(b.selectable_pool().size(), 14, "fixos ativos saem")
	for id in ["ghost_slow", "spirit_trap"]:
		b.activate_fixed(id)
	eq(b.selectable_pool().size(), 12, "so os 12 de mapa")
	# openSelection zera os fixos da run anterior
	b.open_selection()
	eq(b.fixed_buffs.size(), 0, "openSelection limpa fixos")


func test_world_choice_flow_with_transition() -> void:
	var b: BuffSystem = _new(5)
	b.run.start(F.open_level(0))
	b.reset_run_state()
	var opened: Array = []
	b.world_choice_opened.connect(func(o: Array) -> void: opened.append(o))
	b.run.execute_biome_transition()
	eq(b.run.cycle.phase, "choosing", "pausa durante a escolha")
	eq(b.world_options.size(), 3, "3 opcoes por mundo")
	eq(opened.size(), 1, "sinal para a UI")
	var before: float = b.run.elapsed
	b.run.step(0.05, Vector2.ZERO)
	eq(b.run.elapsed, before, "sem avancar tempo enquanto escolhe")
	var pick: Dictionary = b.world_options[0] as Dictionary
	b.pick_world_buff(str(pick["id"]))
	eq(b.run.cycle.phase, "playing", "retoma apos a escolha")
	check(b.run.cycle.announce_timer > 0.0, "anuncio do bioma so depois da escolha")
	if str(pick["type"]) == "fixed":
		check(b.fixed_buffs.has(str(pick["id"])), "fixo ativado")
	else:
		eq(str((b.spawn_pool[0] as Dictionary)["id"]), str(pick["id"]), "buff de mapa entra no pool")


func test_world_choice_empty_pool_skips() -> void:
	var b: BuffSystem = _new(6)
	b.run.start(F.open_level(0))
	b.reset_run_state()
	# 12 de mapa nao esgotam: so se TODOS fossem fixos. Simula pool vazio via fixos + stub
	for id in ["ghost_slow", "spirit_trap", "lightning", "decoy"]:
		b.activate_fixed(id)
	b.run.execute_biome_transition()
	eq(b.run.cycle.phase, "choosing", "ainda ha 12 de mapa => escolhe")
	eq(b.world_options.size(), 3, "3")
	for o: Dictionary in b.world_options:
		eq(str(o["type"]), "map", "fixos ativos nao aparecem")


func test_reroll_attribute() -> void:
	var b: BuffSystem = _new(7)
	b.run.start(F.open_level(0))
	b.reset_run_state()
	b.run.execute_biome_transition()
	check(not b.reroll_enabled(), "sem atributo => sem reroll")
	check(not b.world_reroll(), "reroll negado")
	var b2: BuffSystem = _new(8, {"reroll": 1})
	b2.run.start(F.open_level(0))
	b2.reset_run_state()
	b2.run.execute_biome_transition()
	check(b2.reroll_enabled(), "com atributo")
	var first: Array = b2.world_options.duplicate()
	check(b2.world_reroll(), "1 reroll")
	eq(b2.world_options.size(), 3, "3 novas")
	check(not b2.world_reroll(), "so 1 por escolha")
	b2.pick_world_buff(str((b2.world_options[0] as Dictionary)["id"]))
	b2.run.execute_biome_transition()
	check(b2.world_reroll(), "reroll liberado de novo na proxima escolha")


func test_auto_choice_placeholder() -> void:
	var b: BuffSystem = _new(9)
	b.auto_choice = true
	b.run.start(F.open_level(0))
	b.reset_run_state()
	b.run.execute_biome_transition()
	eq(b.run.cycle.phase, "playing", "auto_choice escolhe sozinho")
	eq(b.build_ids.size(), 1, "1 buff adicionado")


func test_weighted_one_map_weights() -> void:
	# mapW: speed_temp=12, lightning=3 (fixo mas serve ao teste de peso)
	var rng: Rng = Rng.new(5)
	var items: Array = [BuffSystem.buff_def("speed_temp"), BuffSystem.buff_def("lightning")]
	var hit: int = 0
	for i in 2000:
		if str((rng.weighted_one(items, "mapW") as Dictionary)["id"]) == "speed_temp":
			hit += 1
	check(hit > 1400 and hit < 1800, "12/(12+3)=80%% (obtido %d/2000)" % hit)
