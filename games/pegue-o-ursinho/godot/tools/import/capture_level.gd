extends SceneTree
## Captura o render real de uma fase (Visual + DetalhePiso + Decor; Logica oculta) em PNG.
## Uso (NAO headless): "$GODOT_PATH" --path games/pegue-o-ursinho/godot --resolution 576x1024 \
##       --script res://tools/import/capture_level.gd -- <indice 1..10> <saida.png> [all-details]
## "all-details" = teste de estresse: variacoes de piso em TODO o piso (para ver se cobrem bordas).


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var idx: int = int(args[0])
	var out: String = args[1]
	var dir: DirAccess = DirAccess.open("res://levels")
	var files: PackedStringArray = []
	for f: String in dir.get_files():
		if f.begins_with("biome_") and f.ends_with(".tscn"):
			files.append(f)
	files.sort()
	var root: Node2D = (load("res://levels/" + files[idx - 1]) as PackedScene).instantiate() as Node2D
	root.position = Vector2(0, 32)
	get_root().add_child(root)
	if args.size() > 2 and args[2] == "all-details":
		root.set("detail_density", 1.0)
		var det: TileMapLayer = root.get_node("DetalhePiso") as TileMapLayer
		var cfg: Resource = root.get("config") as Resource
		det.tile_set = cfg.get("detail_tiles") as TileSet
		var src: TileSetAtlasSource = det.tile_set.get_source(0) as TileSetAtlasSource
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 5
		for r in 30:
			for c in 18:
				if not bool(root.call("is_wall", c, r)) and rng.randf() < 0.5:
					det.set_cell(Vector2i(c, r), 0, src.get_tile_id(rng.randi() % src.get_tiles_count()))
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	print("salvo ", out)
	quit()
