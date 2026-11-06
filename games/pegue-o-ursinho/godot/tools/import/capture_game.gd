extends SceneTree
## Captura o JOGO real (scenes/game.tscn) com o urso em jogo, em PNG. Roda NAO headless.
## Uso: "$GODOT_PATH" --path games/pegue-o-ursinho/godot --resolution 576x1024 \
##        --script res://tools/import/capture_game.gd -- <bioma 1..10> <saida.png> [buff1,buff2] [dir] [avancar_s]
##   buffs = ids de map buff aplicados antes da captura (ex.: shield,invisible); dir = right|left|up|down
## O urso anda ~1,2 s na direcao dada (teclado simulado) e a camera o segue.


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var biome: int = int(args[0])
	var out: String = args[1]
	var buffs: PackedStringArray = args[2].split(",", false) if args.size() > 2 else PackedStringArray()
	var dir: String = args[3] if args.size() > 3 else "right"
	var g: Node2D = (load("res://scenes/game.tscn") as PackedScene).instantiate() as Node2D
	g.set("rng_seed", 11)
	g.set("show_debug", false)
	get_root().add_child(g)
	await process_frame
	await process_frame
	var run: Object = g.get("run")
	if biome > 1:
		run.cycle.current_biome = biome - 2   # advance() -> biome-1 (0-based)
		run.execute_biome_transition()
	await process_frame
	if args.size() > 4:   # avanca a simulacao N segundos (urso invulneravel) p.ex. para a mare subir
		run.bear.invuln = 9999.0
		for i in int(float(args[4]) / 0.05):
			run.step(0.05, Vector2.ZERO)
		run.bear.invuln = 0.0
	for b: String in buffs:
		(g.get("buffs") as Object).call("apply_map_buff", b)
	Input.action_press("move_" + dir)
	for i in 70:
		await process_frame
	if buffs.has("jump"):
		run.try_jump()
		for i in 5:
			await process_frame
	Input.action_release("move_" + dir)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	print("flooded=", run.mech.get("flooded").size() if run.mech != null and run.mech.get("flooded") != null else -1)
	print("salvo ", out, " bioma=", run.cycle.current_biome + 1, " pos=", run.bear.pos, " ghosts=", run.ghost_sys.ghosts.size())
	quit()
