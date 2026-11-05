extends "res://tests/case.gd"
## Fases: instanciam, Logica == maps.json, validador limpo, painter preenche Visual 19x31.

func _load_level(i: int) -> LevelRoot:
	var ps: PackedScene = load(LevelIndex.scene_path(i)) as PackedScene
	return ps.instantiate() as LevelRoot if ps != null else null


func test_scenes_and_hierarchy() -> void:
	eq(LevelIndex.count(), 10, "10 fases")
	for i in LevelIndex.count():
		var lvl: LevelRoot = _load_level(i)
		check(lvl != null, "fase %d instancia" % (i + 1))
		if lvl == null:
			continue
		for p: String in ["Visual", "DetalhePiso", "Logica", "Decor", "Mecanicas", "Spawns/SpawnUrso", "Spawns/SpawnFantasma"]:
			check(lvl.get_node_or_null(p) != null, "fase %d tem %s" % [i + 1, p])
		check(lvl.config != null and lvl.config.index == i, "fase %d config.index" % (i + 1))
		lvl.free()


func test_logica_matches_legacy() -> void:
	var maps: Array = read_json("res://data/legacy/maps.json") as Array
	var biomes: Array = read_json("res://data/legacy/biomes.json") as Array
	for i in LevelIndex.count():
		var lvl: LevelRoot = _load_level(i)
		var diff: int = 0
		for r in LevelRoot.ROWS:
			for c in LevelRoot.COLS:
				if (1 if lvl.is_wall(c, r) else 0) != int(((maps[i] as Array)[r] as Array)[c]):
					diff += 1
		eq(diff, 0, "fase %d: Logica == BIOME_MAPS (celulas diferentes)" % (i + 1))
		eq(lvl.get_grid().size(), 30, "get_grid 30 linhas")
		var b: Dictionary = biomes[i]
		eq(lvl.bear_spawn_cell(), Vector2i(int(b["bearSpawn"]["c"]), int(b["bearSpawn"]["r"])), "fase %d spawn urso" % (i + 1))
		eq(lvl.ghost_spawn_cell(), Vector2i(int(b["ghostSpawn"]["c"]), int(b["ghostSpawn"]["r"])), "fase %d spawn fantasma" % (i + 1))
		check(lvl.is_wall(-1, 0) and lvl.is_wall(0, 30) and lvl.is_wall(18, 5), "fora do grid e parede")
		lvl.free()


func test_validator_clean() -> void:
	var v: GDScript = load("res://tools/editor/validate_levels.gd") as GDScript
	for i in LevelIndex.count():
		var lvl: LevelRoot = _load_level(i)
		var res: Dictionary = v.call("validate", lvl)
		eq(res["errors"], [], "fase %d sem erros do validador" % (i + 1))
		lvl.free()


func test_validator_rejects() -> void:
	var v: GDScript = load("res://tools/editor/validate_levels.gd") as GDScript
	var lvl: LevelRoot = _load_level(0)
	lvl.set_wall(8, 14, true)  # spawn do urso vira parede
	check(not (v.call("validate", lvl)["errors"] as Array).is_empty(), "spawn em parede reprovado")
	lvl.set_wall(8, 14, false)
	lvl.set_wall(0, 5, false)  # borda aberta
	check(not (v.call("validate", lvl)["errors"] as Array).is_empty(), "borda aberta reprovada")
	lvl.set_wall(0, 5, true)
	lvl.set_wall(0, 0, false)
	lvl.set_wall(1, 0, true)
	lvl.set_wall(0, 1, true)
	lvl.set_wall(1, 1, true)  # celula livre isolada no canto (alem de borda aberta)
	check(not (v.call("validate", lvl)["errors"] as Array).is_empty(), "celula isolada reprovada")
	lvl.free()
	# distancia urso-fantasma
	lvl = _load_level(0)
	(lvl.get_node("Spawns/SpawnFantasma") as Node2D).position = lvl.cell_to_world(Vector2i(9, 14))
	var errs: Array = v.call("validate", lvl)["errors"]
	check(errs.any(func(e: String) -> bool: return e.contains("distancia")), "distancia < 10 reprovada")
	lvl.free()
	# densidade: erro normal, aviso se edicao manual
	lvl = _load_level(0)
	for c in range(1, 17):
		lvl.set_wall(c, 1, true)
		lvl.set_wall(c, 2, true)
		lvl.set_wall(c, 3, true)
	var res: Dictionary = v.call("validate", lvl)
	check((res["errors"] as Array).any(func(e: String) -> bool: return e.contains("densidade")), "densidade fora da meta e erro")
	lvl.edicao_manual = true
	res = v.call("validate", lvl)
	check((res["warnings"] as Array).any(func(w: String) -> bool: return w.contains("densidade")), "densidade manual vira aviso")
	check(not (res["errors"] as Array).any(func(e: String) -> bool: return e.contains("densidade")), "densidade manual nao e erro")
	lvl.free()


func test_painter_fills_visual() -> void:
	for i in LevelIndex.count():
		var lvl: LevelRoot = _load_level(i)
		var visual: TileMapLayer = lvl.get_node("Visual") as TileMapLayer
		eq(visual.position, Vector2(-16, -16), "fase %d: Visual deslocada" % (i + 1))
		var cmap: Dictionary = DualGridPainter.load_corner_map(lvl.config.corner_map_path)
		eq(cmap.size(), 16, "fase %d: corner_map 16 tiles" % (i + 1))
		visual.clear()
		var n: int = DualGridPainter.paint_all(visual, lvl.is_wall, cmap, LevelRoot.COLS, LevelRoot.ROWS)
		eq(n, 19 * 31, "fase %d: painter pintou 19x31" % (i + 1))
		var empty: int = 0
		for vr in 31:
			for vc in 19:
				if visual.get_cell_source_id(Vector2i(vc, vr)) == -1:
					empty += 1
		eq(empty, 0, "fase %d: Visual sem celula vazia" % (i + 1))
		eq(visual.get_used_cells().size(), 19 * 31, "fase %d: so 19x31 usadas" % (i + 1))
		lvl.free()


func test_painter_bitmask_and_pixellab_map() -> void:
	var walls: Callable = func(_c: int, _r: int) -> bool: return true
	eq(DualGridPainter.bitmask(walls, 3, 3), 15, "todos parede = 15")
	var only_se: Callable = func(c: int, r: int) -> bool: return c == 3 and r == 3
	eq(DualGridPainter.bitmask(only_se, 3, 3), DualGridPainter.SE, "so SE")
	var only_nw: Callable = func(c: int, r: int) -> bool: return c == 2 and r == 2
	eq(DualGridPainter.bitmask(only_nw, 3, 3), DualGridPainter.NW, "so NW")
	eq(DualGridPainter.load_corner_map("res://tilesets/corner_maps/pixellab_biome_01_floresta_encantada.json").size(), 16, "corner_map PixelLab 16 tiles")


func test_set_wall_runtime() -> void:
	var lvl: LevelRoot = _load_level(0)
	var counter: Array = [0]
	lvl.grid_changed.connect(func() -> void: counter[0] += 1)
	var before: bool = lvl.is_wall(8, 14)
	lvl.set_wall(8, 14, not before)
	eq(lvl.is_wall(8, 14), not before, "set_wall altera")
	eq(counter[0], 1, "grid_changed emitido")
	eq(lvl.world_to_cell(lvl.cell_to_world(Vector2i(5, 7))), Vector2i(5, 7), "cell<->world")
	lvl.free()
