extends "res://tests/case.gd"
## Fabrica das mecanicas: tipo por bioma == BIOME_MECH, config das fases == legado, fallback
## procedural (Mecanicas vazio) x posicoes a mao, integracao com 10 transicoes de bioma.

const F: GDScript = preload("res://tests/support/run_factory.gd")

const TYPES: Array = ["mushroom", "tide", "ice", "lily", "bats", "windows", "castle", "sky", "fire", "void"]
const CLASS_BY_TYPE: Dictionary = {"mushroom": "MechMushroom", "tide": "MechTide", "ice": "MechIce", "lily": "MechLily",
	"bats": "MechBats", "windows": "MechWindows", "castle": "MechCastle", "sky": "MechSky", "fire": "MechFire", "void": "MechVoid"}


func test_type_per_biome_matches_legacy() -> void:
	for i in 10:
		var run: GameRun = F.make_mech_run(i, false, 1)
		check(run.mech != null, "mecanica do bioma %d" % i)
		eq((run.mech as MechBase).type, TYPES[i], "tipo bioma %d" % i)
		eq(str(GameState.mech_config(i)["type"]), TYPES[i], "legado bioma %d" % i)
		eq((run.mech.get_script() as GDScript).get_global_name(), CLASS_BY_TYPE[TYPES[i]], "classe bioma %d" % i)


func test_real_level_scenes_config_matches_legacy_and_have_empty_mechanics() -> void:
	for i in LevelIndex.count():
		var lvl: LevelRoot = (load(LevelIndex.scene_path(i)) as PackedScene).instantiate() as LevelRoot
		var legacy: Dictionary = GameState.mech_config(i)
		var mech: Dictionary = lvl.config.mech
		eq(lvl.config.mech_type, TYPES[i], "mech_type fase %d" % (i + 1))
		for k: String in legacy:
			if k == "type":
				eq(str(mech[k]), str(legacy[k]), "type fase %d" % (i + 1))
			else:
				near(float(mech[k]), float(legacy[k]), "fase %d: %s" % [i + 1, k])
		eq(lvl.get_mechanic_nodes().size(), 0, "fase %d: Mecanicas vazio => procedural" % (i + 1))
		lvl.free()


func test_config_from_level_overrides_legacy() -> void:
	# o valor do Inspector (BiomeConfig.mech) vence o JSON, desde que preenchido
	var lvl: Node2D = F.make_level(0)
	lvl.config.mech = {"type": "mushroom", "count": 2, "dist": 1, "cd": 0.4}
	var run: GameRun = GameRun.new(1)
	run.start(lvl)
	run.mech = MechFactory.create(run, 0)
	eq((run.mech as MechMushroom).mushrooms.size(), 2, "count do Inspector")


func test_unrelated_markers_keep_procedural() -> void:
	# marcador de outra mecanica (gate) num bioma de cogumelos nao desliga o procedural
	var mk: Node2D = F.marker("gate", Vector2i(5, 5))
	var run: GameRun = F.make_mech_run(0, true, 1, [mk])
	eq((run.mech as MechMushroom).mushrooms.size(), 6, "procedural")
	mk.free()


func test_marker_scenes_load_and_defaults() -> void:
	var kinds: Dictionary = {}
	var dir: DirAccess = DirAccess.open("res://scenes/mechanics")
	check(dir != null, "scenes/mechanics existe")
	for f: String in dir.get_files():
		if not f.ends_with(".tscn"):
			continue
		var n: Node = (load("res://scenes/mechanics/" + f) as PackedScene).instantiate()
		check(n is MechMarker, f + " e MechMarker")
		kinds[str(n.get("kind"))] = true
		check(n.get_node_or_null("Sprite") != null, f + " tem sprite placeholder")
		n.free()
	for k in ["mushroom", "lilypad", "bat_spawn", "window", "gate", "carpet", "platform", "wind", "geyser", "portal"]:
		check(kinds.has(k), "cena para " + k)


func test_full_run_through_all_biomes() -> void:
	var run: GameRun = F.make_full(21, 0, false)
	var b: BuffSystem = run.buffs as BuffSystem
	b.auto_choice = true
	for i in 12:
		var idx: int = run.cycle.current_biome
		check(run.mech != null and (run.mech as MechBase).type == TYPES[idx], "bioma %d com mecanica %s" % [idx, TYPES[idx]])
		for s in 90:
			run.bear.invuln = 100.0
			run.step(1.0 / 30.0, Vector2(1.0 if s % 40 < 20 else -1.0, 1.0 if s % 60 < 30 else -1.0))
		check(run.state == "playing", "run viva no bioma %d" % idx)
		run.execute_biome_transition()
	eq(run.cycle.cycle_count, 1, "voltou ao bioma 1 com ciclo 1")
	check(b.build_ids.size() >= 12, "12 escolhas automaticas")
