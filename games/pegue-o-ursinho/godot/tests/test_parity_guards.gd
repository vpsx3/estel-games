extends "res://tests/case.gd"
## Guardas dos valores FINAIS do rebalanceamento (docs/balanceamento.md): literais de GameplayLits,
## constants.json, ghost_types.json, attrs.json, biomes.json, biome_mech.json. O Godot e a fonte da
## verdade; mudar um numero de balanceamento exige atualizar este teste e docs/balanceamento.md.
## Tambem: efeito CERTO do VfxDirector + icones de bioma resolvendo para arquivos reais.

const F: GDScript = preload("res://tests/support/run_factory.gd")
const TRIALS: int = 150


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_lits_final_values() -> void:
	var expect: Dictionary = {
		"BEAR_BASE_SPEED": 4.3, "JUMP_CD_BASE": 8.0, "CYCLE_SPEED_ADD": 0.12, "CYCLE_RATE_SUB": 1.0,
		"MIN_GHOST_SPAWN_RATE": 6.0, "GHOST_DIFF_CAP": 0.93, "GHOST_CAP_BASE": 5, "GHOST_CAP_PER_PHASE": 1,
		"GHOST_CAP_MAX": 14, "GHOST_CAP_PER_CYCLE": 2, "GHOST_CAP_ABS": 18, "GHOST_SPAWN_GRACE": 0.8,
		"JUMP_LAND_INVULN": 0.3, "INVISIBLE_END_INVULN": 0.6, "BURST_STUN": 1.5, "BURST_PUSH_CELLS": 3.0,
		"STOMP_RADIUS_CELLS": 2.5, "STOMP_STUN": 2.0, "STOMP_PUSH_RADIUS_CELLS": 1.6, "MAGNET_RADIUS_CELLS": 4.0,
		"MAGNET_PULL_CELLS_S": 6.0, "ORB_INTERVAL_POOL_FACTOR": 0.15, "ORB_INTERVAL_MIN": 4.0,
		"HONEY_PICKUP_PER_PHASE": 1, "HONEY_PICKUP_MAX": 15, "BIOME_CLEAR_HONEY": 10, "ICE_MAX_SPEED_MULT": 1.65,
		"PUSH_CELLS": 1.6, "GEYSER_FIRE_AT": 0.6,
	}
	var consts: Dictionary = (GameplayLits as GDScript).get_script_constant_map()
	for k: String in expect:
		check(consts.has(k), "constante existe: " + k)
		near(float(consts.get(k, -999.0)), float(expect[k]), k)
	var fx: Dictionary = GameplayLits.BUFF_FX
	check(not fx.has("dash") and not fx.has("ghost_slow"), "BUFF_FX sem dash/ghost_slow")
	near(float((fx["spirit_trap"] as Dictionary)["dur"]), 4.0, "spirit_trap dur 4")


func test_data_final_values() -> void:
	var c: Dictionary = GameState.constants
	near(float(c["GHOST_PHASE_SCALING"]), 0.03, "GHOST_PHASE_SCALING")
	near(float(c["HONEY_SPAWN_INTERVAL"]), 10.0, "HONEY_SPAWN_INTERVAL")
	near(float(c["POISON_RADIUS"]), 64.0, "POISON_RADIUS")
	near(float(c["POISON_DEBUFF"]), 0.75, "POISON_DEBUFF")
	near(float(c["POISON_COOLDOWN"]), 3000.0, "POISON_COOLDOWN")
	near(float(c["SPRAY_SLOW_MULT"]), 0.6, "SPRAY_SLOW_MULT")
	near(float(c["SPRAY_SLOW_DUR"]), 4.0, "SPRAY_SLOW_DUR")
	eq(c["FIXED_INTERVALS"], {"ghost_slow": 12.0, "spirit_trap": 12.0, "lightning": 35.0, "decoy": 25.0}, "FIXED_INTERVALS")
	var gt: Dictionary = GameState.ghost_types
	var spd: Dictionary = {"comum": 2.9, "rapido": 3.9, "pesado": 1.9, "errante": 2.9, "venenoso": 2.55}
	var mp: Dictionary = {"comum": 0, "rapido": 1, "pesado": 1, "errante": 2, "venenoso": 3}
	for k: String in spd:
		near(float((gt[k] as Dictionary)["speed"]), float(spd[k]), "speed " + k)
		eq(int((gt[k] as Dictionary)["minPhase"]), int(mp[k]), "minPhase " + k)
	var sp: Array = [0.62, 0.70, 0.78, 0.85, 0.91, 0.97, 1.01, 1.05, 1.08, 1.12]
	var rt: Array = [12, 12, 11, 11, 10, 10, 9, 9, 8, 8]
	for i in 10:
		near(float((GameState.biomes[i] as Dictionary)["ghostSpeed"]), float(sp[i]), "biomes.json ghostSpeed %d" % i)
		near(float((GameState.biomes[i] as Dictionary)["ghostSpawnRate"]), float(rt[i]), "biomes.json ghostSpawnRate %d" % i)
		# o BiomeConfig (.tres) e lido ANTES do JSON por run._biome_base(): precisa estar igual
		var cfg: BiomeConfig = load("res://data/biomes/biome_%02d.tres" % (i + 1)) as BiomeConfig
		near(cfg.ghost_speed, float(sp[i]), "BiomeConfig ghost_speed %d" % i)
		near(cfg.ghost_spawn_rate, float(rt[i]), "BiomeConfig ghost_spawn_rate %d" % i)
	var d: Dictionary = (GameState.attrs["defs"] as Dictionary)
	for i in 10:
		near(float(((d["speed_base"] as Dictionary)["values"] as Array)[i]), 0.04 * (i + 1), "speed_base values %d" % i)
		near(float(((d["jump_cd"] as Dictionary)["values"] as Array)[i]), 0.04 * (i + 1), "jump_cd values %d" % i)
		near(float(((d["jump_ext"] as Dictionary)["values"] as Array)[i]), 0.045 * (i + 1), "jump_ext values %d" % i)
	eq(int(((d["double_jump"] as Dictionary)["costs"] as Array)[0]), 1500, "double_jump custo")
	eq(int(((d["reroll"] as Dictionary)["costs"] as Array)[0]), 1200, "reroll custo")
	var bm: Dictionary = GameState.biome_mech
	near(float((bm["4"] as Dictionary)["freeze"]), 1.2, "bats.freeze")
	near(float((bm["5"] as Dictionary)["frac"]), 0.08, "windows.frac")
	near(float((bm["5"] as Dictionary)["cd"]), 15.0, "windows.cd")
	near(float((bm["6"] as Dictionary)["gateFrac"]), 0.35, "castle.gateFrac")
	# mecanicas dos .tres (BiomeConfig.mech) iguais ao JSON
	near(float((load("res://data/biomes/biome_05.tres") as BiomeConfig).mech["freeze"]), 1.2, "tres bats.freeze")
	near(float((load("res://data/biomes/biome_06.tres") as BiomeConfig).mech["frac"]), 0.08, "tres windows.frac")
	near(float((load("res://data/biomes/biome_06.tres") as BiomeConfig).mech["cd"]), 15.0, "tres windows.cd")
	near(float((load("res://data/biomes/biome_07.tres") as BiomeConfig).mech["gateFrac"]), 0.35, "tres castle.gateFrac")


## Empurrao de captura: o fantasma anda exatamente TILE*PUSH_CELLS para longe do urso.
func test_push_ghost_moves_exact_cells() -> void:
	var run: GameRun = F.make_run(1, true)
	run.bear.pos = Units.cell_center(8, 14)
	var g: GhostModel = run.ghost_sys.make_ghost("comum", run.bear.pos + Vector2(Units.TILE * 2.0, 0.0))
	run.ghost_sys.ghosts.append(g)
	var before: Vector2 = g.pos
	run.ghost_sys.push_ghost(g)
	near(g.pos.distance_to(before), Units.TILE * GameplayLits.PUSH_CELLS, "deslocamento = TILE*PUSH_CELLS", 0.01)
	check(g.pos.x > before.x and absf(g.pos.y - before.y) < 0.01, "empurra para longe do urso")


## Momento da erupcao do geiser: fase 0, sin(t*geySpeed) cruza 0.6 em t = asin(0.6)/geySpeed.
func test_geyser_eruption_moment() -> void:
	var run: GameRun = F.make_mech_run(8, true, 9)
	var m: MechFire = run.mech as MechFire
	var speed: float = m.cfg_f("geySpeed")
	near(speed, 0.8, "geySpeed legado")
	m.geysers = [{"cell": Vector2i(6, 12), "phase": 0.0}]
	var th: float = asin(GameplayLits.GEYSER_FIRE_AT)
	run.elapsed = (th - 0.02) / speed
	eq(m.geyser_state(m.geysers[0]), "warming", "antes do limiar 0.6 ainda nao e fogo")
	run.elapsed = (th + 0.02) / speed
	eq(m.geyser_state(m.geysers[0]), "fire", "depois do limiar 0.6 e fogo")
	# janela de fogo = [asin(.6), PI - asin(.6)]: progresso 0.5 no pico
	run.elapsed = (PI / 2.0) / speed
	near(m.fire_progress(m.geysers[0]), 0.5, "pico da janela de fogo = 0.5", 0.001)
	run.elapsed = (PI - th - 0.02) / speed
	eq(m.geyser_state(m.geysers[0]), "fire", "ainda fogo logo antes do fim")
	run.elapsed = (PI - th + 0.02) / speed
	eq(m.geyser_state(m.geysers[0]), "warming", "fim da janela de fogo simetrico")


# ---------------------------------------------------------------- VfxDirector
func _vfx_ids(host: Node) -> Array:
	var out: Array = []
	for c: Node in host.get_children():
		if c is VfxPlayer and not c.is_queued_for_deletion():
			out.append((c as VfxPlayer).vfx_id)
	out.sort()
	return out


func _clear(host: Node) -> void:
	for c: Node in host.get_children():
		if c is VfxPlayer:
			host.remove_child(c)
			c.free()


func test_vfx_director_right_effect_per_event() -> void:
	var run: GameRun = F.make_full(5)
	var host: Node2D = Node2D.new()
	_tree().root.add_child(host)
	var d: VfxDirector = VfxDirector.new()
	d.bind(run, host)
	host.add_child(d)
	d._process(0.0)   # semeia estado (fantasmas existentes nao disparam ghost_spawn)
	_clear(host)

	Events.bear_jumped.emit()
	eq(_vfx_ids(host), ["jump"], "pulo -> jump")
	_clear(host)

	Events.buff_activated.emit("freeze_all")
	eq(_vfx_ids(host), ["freeze_all"], "buff freeze_all -> freeze_all")
	_clear(host)

	Events.buff_activated.emit("teleport")
	eq(_vfx_ids(host), ["teleport"], "buff teleport -> teleport")
	_clear(host)

	Events.buff_activated.emit("light_bomb")
	eq(_vfx_ids(host), ["light_bomb"], "buff light_bomb -> light_bomb")
	_clear(host)

	Events.honey_collected.emit(5)
	eq(_vfx_ids(host), ["honey_pickup"], "mel -> honey_pickup")
	_clear(host)

	Events.biome_changed.emit(1)
	eq(_vfx_ids(host), ["biome_transition"], "bioma -> biome_transition")
	_clear(host)

	run.shield_charges = 1
	d._process(0.0)
	eq(_vfx_ids(host), ["shield"], "escudo ativo -> shield (loop)")
	run.shield_charges = 0
	d._process(0.0)
	check("shield_break" in _vfx_ids(host), "escudo quebrado -> shield_break")
	_clear(host)
	d._process(0.0)
	_clear(host)

	run.bear.poisoned = true
	d._process(0.0)
	eq(_vfx_ids(host), ["poisoned"], "veneno -> poisoned")
	run.bear.poisoned = false
	d._process(0.0)
	_clear(host)

	Events.game_over.emit({})
	eq(_vfx_ids(host), ["caught"], "captura/game over -> caught")

	host.queue_free()
	await _tree().process_frame


# ---------------------------------------------------------------- icones de bioma (F1)
func test_biome_icon_keys_resolve_to_files() -> void:
	for b in 10:
		var key: String = "biome_%02d" % (b + 1)   # chave usada por hud.gd (banner/icone de bioma)
		var path: String = UiIcons.DIR + str(UiIcons.ALIAS.get(key, key)) + ".png"
		check(ResourceLoader.exists(path), "arquivo de icone existe: " + path)
		var tr: TextureRect = TextureRect.new()
		UiIcons.apply(tr, key, UiIcons.color_for(key), "B")
		check(not tr.has_meta("placeholder"), "sem placeholder: " + key)
		tr.free()
	# nenhum script de UI pode montar chave de bioma sem zero a esquerda
	var dir: DirAccess = DirAccess.open("res://scripts/ui")
	for f: String in dir.get_files():
		if f.ends_with(".gd"):
			var src: String = FileAccess.get_file_as_string("res://scripts/ui/" + f)
			check(not ("\"biome_%d\"" in src), "%s nao usa chave biome_%%d" % f)
	var hud: String = FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	check("\"biome_%02d\" % (b + 1)" in hud, "hud.gd usa biome_%02d")
	var res: String = FileAccess.get_file_as_string("res://scripts/ui/result_screen.gd")
	check(not ("biome_icon" in res or "UiIcons.apply(%Biome" in res), "result_screen nao usa icone de bioma")
