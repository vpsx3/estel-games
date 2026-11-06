extends "res://tests/case.gd"
## E8 parte 1: arte integrada (tilesets Wang reais, detalhes, decor, urso, mecanicas, VFX).

const SLUGS: Array[String] = ["floresta_encantada", "praia_dos_coqueiros", "montanha_gelada", "pantano_verde",
	"caverna_dos_ecos", "vila_assombrada", "castelo_do_rei", "ilhas_flutuantes", "inferno_fofo", "dimensao_dos_fantasmas"]
const BEAR_ANIMS: Array[String] = ["idle", "walk", "dash", "jump"]
const MECH_SLOTS: Array[String] = ["mushroom", "water", "foam", "lilypad", "bat", "window_eyes", "gate", "carpet",
	"platform", "geyser", "fire_trail", "portal"]


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_tilesets_and_corner_maps() -> void:
	for i in 10:
		var cfg: BiomeConfig = load("res://data/biomes/biome_%02d.tres" % (i + 1)) as BiomeConfig
		check(cfg != null, "config %d" % (i + 1))
		if cfg == null:
			continue
		eq(cfg.corner_map_path, "res://tilesets/corner_maps/biome_%02d_%s.json" % [i + 1, SLUGS[i]], "corner_map_path %d" % (i + 1))
		eq(DualGridPainter.load_corner_map(cfg.corner_map_path).size(), 16, "16 mascaras bioma %d" % (i + 1))
		check(cfg.tileset != null and cfg.tileset.get_source_count() == 1, "tileset bioma %d" % (i + 1))
		eq(cfg.tileset.tile_size, Vector2i(32, 32), "tile 32 bioma %d" % (i + 1))
		var src: TileSetAtlasSource = cfg.tileset.get_source(0) as TileSetAtlasSource
		check(src.get_tiles_count() >= 16, ">=16 tiles bioma %d" % (i + 1))
		check(cfg.detail_tiles != null and (cfg.detail_tiles.get_source(0) as TileSetAtlasSource).get_tiles_count() == 6, "6 variacoes bioma %d" % (i + 1))
		var img: Image = (src.texture as Texture2D).get_image()
		var semi: int = 0
		for y in img.get_height():
			for x in img.get_width():
				var a: float = img.get_pixel(x, y).a
				if a > 0.0 and a < 1.0:
					semi += 1
		eq(semi, 0, "alfa 0/255 bioma %d" % (i + 1))


func test_levels_have_art() -> void:
	for i in 10:
		var lvl: Node2D = (load(LevelIndex.scene_path(i)) as PackedScene).instantiate() as Node2D
		var decor: int = lvl.get_node("Decor").get_child_count()
		check(decor >= 6 and decor <= 12, "decor 6-12 fase %d (%d)" % [i + 1, decor])
		# detalhes opcionais (mapas de corredor podem ter 0), mas nunca encostados em parede (cobririam a borda do Visual dual)
		for dc: Vector2i in (lvl.get_node("DetalhePiso") as TileMapLayer).get_used_cells():
			for dr2 in [-1, 0, 1]:
				for dc2 in [-1, 0, 1]:
					check(not bool(lvl.call("is_wall", dc.x + dc2, dc.y + dr2)), "detalhe junto a parede fase %d %s" % [i + 1, str(dc)])
		eq(lvl.get_node("Mecanicas").get_child_count(), 0, "Mecanicas intocada fase %d" % (i + 1))
		for d: Node in lvl.get_node("Decor").get_children():
			var c: Vector2i = lvl.world_to_cell((d as Node2D).position)
			check(not lvl.is_wall(c.x, c.y), "decor fora de parede fase %d" % (i + 1))
		lvl.free()


func test_bear_frames() -> void:
	var sf: SpriteFrames = load("res://assets/actors/bear/bear_frames.tres") as SpriteFrames
	check(sf != null, "bear_frames carrega")
	for a: String in BEAR_ANIMS:
		for d: String in ["south", "north", "east", "west"]:
			check(sf.has_animation("%s_%s" % [a, d]), "anim %s_%s" % [a, d])
	check(sf.has_animation("caught") and sf.has_animation("celebrate"), "caught/celebrate")
	check(not sf.get_animation_loop("jump_south") and sf.get_animation_loop("walk_east"), "loops coerentes")
	eq(sf.get_frame_texture("idle_south", 0).get_size(), Vector2(64, 64), "canvas 64 (corpo 48)")


func test_mechanic_and_vfx_frames() -> void:
	for s: String in MECH_SLOTS:
		check(MechBase.frames(s) != null, "SpriteFrames mecanica " + s)
	check(MechBase.frame_at("mushroom", "idle", 0.3) != null and MechBase.frame_p("mushroom", "bounce", 0.5) != null, "cogumelo idle/bounce")
	eq(MechBase.frames("bat").get_animation_names().size(), 4, "morcego 4 direcoes")
	var dir: DirAccess = DirAccess.open("res://assets/vfx")
	var n: int = 0
	for id: String in dir.get_directories():
		var sf: SpriteFrames = load("res://assets/vfx/%s/%s_frames.tres" % [id, id]) as SpriteFrames
		check(sf != null and sf.get_frame_count("default") > 0 and sf.has_meta("anchor") and sf.has_meta("offset"), "vfx " + id)
		n += 1
	eq(n, 28, "28 VFX (16 buffs + 9 eventos + 3 ambiente)")
	check(not FileAccess.file_exists("res://assets/_placeholder/actors/ghost_sheet.png"), "ghost_sheet placeholder removido")
	check(not FileAccess.file_exists("res://assets/_placeholder/actors/bear_sheet.png"), "bear_sheet legado removido")


func test_vfx_director_runs_all_buffs() -> void:
	var g: Node2D = (load("res://scenes/game.tscn") as PackedScene).instantiate() as Node2D
	g.set("rng_seed", 5)
	g.set("show_debug", false)
	_tree().root.add_child(g)
	await _tree().process_frame
	var buffs: BuffSystem = g.get("buffs") as BuffSystem
	var run: GameRun = g.get("run") as GameRun
	for b: Dictionary in BuffSystem.all_buffs():
		if str(b["type"]) == "map":
			buffs.apply_map_buff(str(b["id"]))
	run.try_jump()
	run.ghost_sys.ghosts[0].frozen = 2.0
	run.ghost_sys.ghosts[0].trapped = 2.0
	for i in 20:
		await _tree().process_frame
	var fx: int = 0
	for c: Node in g.get_node("World").get_children():
		if c is VfxPlayer:
			fx += 1
	check(fx > 0, "VfxPlayer instanciados (%d)" % fx)
	check(g.get_node("World").get_child_count() > 3, "mundo montado")
	g.queue_free()
	await _tree().process_frame
