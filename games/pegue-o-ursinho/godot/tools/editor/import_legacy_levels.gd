@tool
extends SceneTree
## Importacao inicial: gera data/biomes/biome_XX.tres, levels/biome_XX_<slug>.tscn e
## levels/_template_biome.tscn a partir de data/legacy/*.json. ATENCAO: sobrescreve as cenas
## (apaga edicoes manuais). Uso: --headless --path <projeto> --script res://tools/editor/import_legacy_levels.gd

const DIR: String = "res://data/legacy/"
# Metas de densidade REAIS dos BIOME_MAPS do HTML (docs/auditoria.md); o generate_biome_maps.py
# usa metas de projeto diferentes (0.38/0.32/0.48/0.52/...), que nao descrevem os mapas atuais.
const TARGETS: Array[float] = [0.37, 0.31, 0.49, 0.37, 0.48, 0.34, 0.66, 0.47, 0.62, 0.71]


func _j(f: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(DIR + f))


func _initialize() -> void:
	var maps: Array = _j("maps.json") as Array
	var biomes: Array = _j("biomes.json") as Array
	var mech: Dictionary = _j("biome_mech.json") as Dictionary
	var names_en: Dictionary = (_j("strings_en.json") as Dictionary)["biome_names"] as Dictionary
	var logic_ts: TileSet = load("res://tilesets/editor_logic.tres") as TileSet
	for i in LevelIndex.count():
		var b: Dictionary = biomes[i] as Dictionary
		var slug: String = LevelIndex.SLUGS[i]
		var m: Dictionary = mech[str(i)] as Dictionary
		var cfg: BiomeConfig = BiomeConfig.new()
		cfg.index = i
		cfg.slug = slug
		cfg.name_pt = b["name"]
		cfg.name_en = names_en[str(i + 1)]
		cfg.icon = b["icon"]
		cfg.wall_tint = Color.html(b["wallTint"])
		cfg.bg_color = Color.html(b["bgColor"])
		cfg.ghost_speed = float(b["ghostSpeed"])
		cfg.ghost_spawn_rate = float(b["ghostSpawnRate"])
		cfg.mech_type = m["type"]
		cfg.mech = m.duplicate(true)
		cfg.target_wall_density = TARGETS[i]
		cfg.tileset = load("res://tilesets/placeholder/%s.tres" % slug) as TileSet
		cfg.corner_map_path = "res://tilesets/corner_maps/biome_%s.json" % slug.replace("-", "_")
		var cpath: String = LevelIndex.config_path(i)
		_check(ResourceSaver.save(cfg, cpath), cpath)
		cfg = load(cpath) as BiomeConfig
		var bear: Dictionary = b["bearSpawn"] as Dictionary
		var ghost: Dictionary = b["ghostSpawn"] as Dictionary
		var root: LevelRoot = _build("Biome%02d" % (i + 1), cfg, logic_ts, maps[i] as Array,
			Vector2i(int(bear["c"]), int(bear["r"])), Vector2i(int(ghost["c"]), int(ghost["r"])))
		_save(root, LevelIndex.scene_path(i))
	# template: borda de parede, interior livre
	var g: Array = []
	for r in LevelRoot.ROWS:
		var row: Array = []
		for c in LevelRoot.COLS:
			row.append(1 if (r == 0 or c == 0 or r == LevelRoot.ROWS - 1 or c == LevelRoot.COLS - 1) else 0)
		g.append(row)
	var t: LevelRoot = _build("BiomeXX", load(LevelIndex.config_path(0)) as BiomeConfig, logic_ts, g, Vector2i(8, 14), Vector2i(16, 28))
	_save(t, "res://levels/_template_biome.tscn")
	print("importacao concluida: 10 fases + template")
	quit(0)


func _check(err: int, what: String) -> void:
	if err != OK:
		printerr("erro %d ao salvar %s" % [err, what])
		quit(1)


func _node(parent: Node, n: Node, nm: String, owner_: Node) -> Node:
	n.name = nm
	parent.add_child(n)
	n.owner = owner_
	return n


func _build(root_name: String, cfg: BiomeConfig, logic_ts: TileSet, grid: Array, bear: Vector2i, ghost: Vector2i) -> LevelRoot:
	var root: LevelRoot = LevelRoot.new()
	root.name = root_name
	root.config = cfg
	var visual: TileMapLayer = _node(root, TileMapLayer.new(), "Visual", root) as TileMapLayer
	visual.tile_set = cfg.tileset
	visual.position = Vector2(-LevelRoot.CELL / 2.0, -LevelRoot.CELL / 2.0)
	_node(root, TileMapLayer.new(), "DetalhePiso", root)
	var logica: TileMapLayer = _node(root, TileMapLayer.new(), "Logica", root) as TileMapLayer
	logica.tile_set = logic_ts
	var decor: Node2D = _node(root, Node2D.new(), "Decor", root) as Node2D
	decor.y_sort_enabled = true
	_node(root, Node2D.new(), "Mecanicas", root)
	var spawns: Node2D = _node(root, Node2D.new(), "Spawns", root) as Node2D
	var mu: Marker2D = _node(spawns, Marker2D.new(), "SpawnUrso", root) as Marker2D
	mu.position = root.cell_to_world(bear)
	var mf: Marker2D = _node(spawns, Marker2D.new(), "SpawnFantasma", root) as Marker2D
	mf.position = root.cell_to_world(ghost)
	root.load_grid(grid)
	var cmap: Dictionary = DualGridPainter.load_corner_map(cfg.corner_map_path)
	DualGridPainter.paint_all(visual, root.is_wall, cmap, LevelRoot.COLS, LevelRoot.ROWS)
	return root


func _save(root: LevelRoot, path: String) -> void:
	var ps: PackedScene = PackedScene.new()
	_check(ps.pack(root), "pack " + path)
	_check(ResourceSaver.save(ps, path), path)
	root.free()
