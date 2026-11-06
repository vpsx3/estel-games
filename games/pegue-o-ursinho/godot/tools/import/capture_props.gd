extends SceneTree
## Captura o JOGO real (nao headless) com os 5 tipos de fantasma, mel, orbes (3 raridades) e isca forcados
## perto do urso. Uso: "$GODOT_PATH" --path . --resolution 576x1024 --script res://tools/import/capture_props.gd -- <bioma> <saida.png> [estado]
##   estado (opcional) = frozen | trapped | boost  (aplicado a todos os fantasmas)


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var biome: int = int(args[0])
	var out: String = args[1]
	var state: String = args[2] if args.size() > 2 else ""
	var g: Node2D = (load("res://scenes/game.tscn") as PackedScene).instantiate() as Node2D
	g.set("rng_seed", 11)
	g.set("show_debug", false)
	get_root().add_child(g)
	await process_frame
	await process_frame
	var run: Object = g.get("run")
	var GC: GDScript = load("res://scripts/gameplay/grid_collision.gd")
	var UN: GDScript = load("res://scripts/core/units.gd")   # (classes nomeadas so por load: autoloads ainda nao existem ao compilar o script)
	if biome > 1:
		run.cycle.current_biome = biome - 2
		run.execute_biome_transition()
	await process_frame
	run.bear.invuln = 9999.0
	run.cycle.ghost_hide_timer = 0.0
	run.ghost_sys.ghosts.clear()
	var cells: Array = GC.free_cells(run.level)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return UN.cell_center(a.x, a.y).distance_to(run.bear.pos) < UN.cell_center(b.x, b.y).distance_to(run.bear.pos))
	var used: Array[Vector2i] = []
	var pick: Callable = func() -> Vector2:   # proximo ponto livre com 2 celulas de folga dos ja usados
		for c: Vector2i in cells:
			var ok: bool = UN.cell_center(c.x, c.y).distance_to(run.bear.pos) > 70.0
			for u: Vector2i in used:
				if absi(u.x - c.x) < 2 and absi(u.y - c.y) < 2:
					ok = false
			if ok:
				used.append(c)
				return UN.cell_center(c.x, c.y)
		return run.bear.pos
	var dirs: Array = ["south", "east", "north", "west", "south"]
	var i: int = 0
	for t: String in ["comum", "rapido", "pesado", "errante", "venenoso"]:
		var gm: Object = run.ghost_sys.make_ghost(t, pick.call() as Vector2)
		gm.facing = dirs[i]
		gm.palette_index = i
		match state:
			"frozen": gm.frozen = 60.0
			"trapped": gm.trapped = 60.0
			"boost": gm.boost_timer = 60.0
		run.ghost_sys.ghosts.append(gm)
		i += 1
	var buffs: Object = run.buffs
	buffs.collectibles.clear()
	for spec: Array in [["freeze_all", "map", "comum"], ["shield", "map", "incomum"], ["lightning", "map", "raro"], ["speed_base", "passive", "comum"], ["decoy", "map", "incomum"]]:
		buffs.collectibles.append({"id": spec[0], "type": spec[1], "icon": "", "rar": spec[2], "pos": pick.call(), "life": 9999.0, "born": float(i)})
		i += 1
	run.honey.drops.clear()
	for k in 3:
		run.honey.drops.append({"pos": pick.call(), "life": 9999.0, "born": float(k) * 2.0})
	run.decoy = {"pos": pick.call(), "life": 9999.0, "max_life": 9999.0}
	for k in 6:
		await process_frame
	g.set_process(false)   # congela a simulacao; as views continuam animando
	for k in 150:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	print("salvo ", out, " ghosts=", run.ghost_sys.ghosts.size(), " collect=", buffs.collectibles.size())
	quit()
