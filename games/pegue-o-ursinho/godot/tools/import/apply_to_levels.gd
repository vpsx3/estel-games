extends SceneTree
## E8: aplica a arte integrada nas 10 fases SEM mexer em Logica/Spawns/Mecanicas:
##  - repinta Visual com o tileset real (config.tileset + corner_map_path ja apontam para o real);
##  - DetalhePiso: "Espalhar detalhes" com seed fixa e densidade esparsa;
##  - Decor: 6-12 objetos (cenas leves de assets/decor/<slug>/) em celulas livres afastadas dos spawns.
## Idempotente (refaz DetalhePiso e Decor a cada execucao).
## Uso: "$GODOT_PATH" --headless --path games/pegue-o-ursinho/godot --script res://tools/import/apply_to_levels.gd

const DETAIL_DENSITY: float = 0.10   # alvo: fracao do piso total
const MIN_SPAWN_DIST: int = 5      # celulas (Chebyshev) ate os spawns
const MIN_DECOR_DIST: int = 3      # celulas entre decor
const SEED_BASE: int = 7000


func _initialize() -> void:
	var dir: DirAccess = DirAccess.open("res://levels")
	var files: PackedStringArray = []
	for f: String in dir.get_files():
		if f.begins_with("biome_") and f.ends_with(".tscn"):
			files.append(f)
	files.sort()
	var ok: bool = true
	for i in files.size():
		ok = _process_level(i, files[i]) and ok
	ok = _repaint_template() and ok
	quit(0 if ok else 1)


## levels/_template_biome.tscn: so repinta o Visual com o tileset real do bioma 1.
func _repaint_template() -> bool:
	var path: String = "res://levels/_template_biome.tscn"
	var root: Node2D = (load(path) as PackedScene).instantiate() as Node2D
	get_root().add_child(root)
	root.call("repaint_visual")
	(root.get_node("Logica") as CanvasItem).visible = true
	var ps: PackedScene = PackedScene.new()
	var err: int = ps.pack(root)
	if err == OK:
		err = ResourceSaver.save(ps, path)
	print("_template_biome.tscn: save=%s" % error_string(err))
	get_root().remove_child(root)
	root.free()
	return err == OK


func _process_level(i: int, file: String) -> bool:
	var path: String = "res://levels/" + file
	var slug: String = file.trim_prefix("biome_%02d_" % (i + 1)).trim_suffix(".tscn")
	var root: Node2D = (load(path) as PackedScene).instantiate() as Node2D
	get_root().add_child(root)
	root.set("detail_density", DETAIL_DENSITY)
	root.set("detail_seed", 1337 + i)
	root.call("repaint_visual")
	root.call("scatter_details")
	var n_decor: int = _place_decor(root, slug, i)
	(root.get_node("Logica") as CanvasItem).visible = true   # runtime a esconde; nao gravar assim
	var det: TileMapLayer = root.get_node("DetalhePiso") as TileMapLayer
	var vis: TileMapLayer = root.get_node("Visual") as TileMapLayer
	var ps: PackedScene = PackedScene.new()
	var err: int = ps.pack(root)
	if err == OK:
		err = ResourceSaver.save(ps, path)
	print("%s: visual=%d detalhes=%d decor=%d save=%s" % [file, vis.get_used_cells().size(), det.get_used_cells().size(), n_decor, error_string(err)])
	get_root().remove_child(root)
	root.free()
	return err == OK


func _place_decor(root: Node2D, slug: String, i: int) -> int:
	var decor: Node2D = root.get_node("Decor") as Node2D
	for c: Node in decor.get_children():
		decor.remove_child(c)
		c.free()
	var scenes: Array[PackedScene] = []
	var ddir: DirAccess = DirAccess.open("res://assets/decor/" + slug)
	if ddir == null:
		return 0
	var names: PackedStringArray = []
	for f: String in ddir.get_files():
		if f.ends_with(".tscn"):
			names.append(f)
	names.sort()
	for f: String in names:
		scenes.append(load("res://assets/decor/%s/%s" % [slug, f]) as PackedScene)
	if scenes.is_empty():
		return 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED_BASE + i
	var sp_b: Vector2i = root.call("bear_spawn_cell") as Vector2i
	var sp_g: Vector2i = root.call("ghost_spawn_cell") as Vector2i
	var tiers: Array = [[], [], []]   # 8 vizinhas livres / 4 livres / qualquer livre
	for r in range(1, 29):
		for c in range(1, 17):
			if bool(root.call("is_wall", c, r)):
				continue
			var cell: Vector2i = Vector2i(c, r)
			if _cheb(cell, sp_b) < MIN_SPAWN_DIST or _cheb(cell, sp_g) < MIN_SPAWN_DIST:
				continue
			var free4: bool = not (bool(root.call("is_wall", c + 1, r)) or bool(root.call("is_wall", c - 1, r)) or bool(root.call("is_wall", c, r + 1)) or bool(root.call("is_wall", c, r - 1)))
			var free8: bool = free4
			if free8:
				for dr in range(-1, 2):
					for dc in range(-1, 2):
						if bool(root.call("is_wall", c + dc, r + dr)):
							free8 = false
			var tier_idx: int = 0 if free8 else (1 if free4 else 2)
			(tiers[tier_idx] as Array).append(cell)
	var target: int = 6 + rng.randi() % 7   # 6..12
	var placed: Array[Vector2i] = []
	for tier: Array in tiers:
		var cand: Array = tier.duplicate()
		while placed.size() < target and not cand.is_empty():
			var k: int = rng.randi() % cand.size()
			var cell: Vector2i = cand[k] as Vector2i
			cand.remove_at(k)
			var near: bool = false
			for p: Vector2i in placed:
				if _cheb(p, cell) < MIN_DECOR_DIST:
					near = true
					break
			if near:
				continue
			var inst: Node2D = scenes[placed.size() % scenes.size()].instantiate() as Node2D
			inst.name = "%s_%02d" % [inst.name, placed.size() + 1]
			inst.position = root.call("cell_to_world", cell) as Vector2
			decor.add_child(inst)
			inst.owner = root
			placed.append(cell)
	return placed.size()


func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
