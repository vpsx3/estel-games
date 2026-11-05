extends "res://tests/case.gd"
## Camera (CAM_CONFIG/smoothing), joystick virtual, teclado e a cena game.tscn.

const F: GDScript = preload("res://tests/support/run_factory.gd")


func test_camera_zoom_and_target() -> void:
	var m: Dictionary = CameraRig.cam_config("mobile")
	var d: Dictionary = CameraRig.cam_config("desktop")
	near(CameraRig.zoom_for(Vector2(576, 1024), m), 2.0, "mobile 9 tiles em 576px")
	near(CameraRig.zoom_for(Vector2(1920, 1080), d), 1920.0 / 576.0, "desktop 18 tiles, aspecto <= 1.78")
	near(CameraRig.zoom_for(Vector2(2400, 1000), d), 1000.0 * 1.78 / 576.0, "maxAspect corta a largura")
	var view: Vector2 = CameraRig.view_world_size(Vector2(576, 1024), m)
	eq(view, Vector2(288, 512), "vista mobile em px de mundo")
	eq(CameraRig.target_top_left(Vector2(0, 0), view), Vector2(0, 0), "trava no canto")
	eq(CameraRig.target_top_left(Vector2(288, 480), view), Vector2(144, 224), "centra no urso")
	eq(CameraRig.target_top_left(Vector2(576, 960), view), Vector2(288, 448), "trava no canto oposto")
	var dv: Vector2 = CameraRig.view_world_size(Vector2(576, 1024), d)
	eq(CameraRig.target_top_left(Vector2(100, 100), dv), Vector2(0, -32), "vista >= mapa: centraliza")
	near(float(m["smooth"]), 0.18, "smooth do CAM_CONFIG")
	near(CameraRig.smooth_alpha(0.18, 1.0 / 60.0), 0.18, "alpha @60fps = smooth")
	near(CameraRig.smooth_alpha(0.18, 1.0 / 30.0), 1.0 - 0.82 * 0.82, "alpha @30fps composto")


func test_virtual_joystick() -> void:
	var j: PouJoystick = PouJoystick.new()
	near(PouJoystick.radius(), 42.0, "JOY_RADIUS")
	j.start(Vector2(100, 100), Vector2(142, 100))
	check(j.active, "ativo")
	eq(j.vec, Vector2(1, 0), "borda do raio = 1")
	j.move(Vector2(107, 100))
	eq(j.vec, Vector2.ZERO, "zona morta 0.18")
	j.move(Vector2(184, 100))
	eq(j.vec, Vector2(2, 0), "nao limitado a 1 (como o JS)")
	near(j.knob_offset().length(), 42.0, "knob limitado ao raio")
	j.end()
	check(not j.active and j.vec == Vector2.ZERO, "fim zera")
	eq(InputReader.move_vector(j), InputReader.keyboard_vector(), "sem joystick => teclado")


func test_keyboard_actions() -> void:
	Input.action_press("move_left")
	Input.action_press("move_up")
	eq(InputReader.keyboard_vector(), Vector2(-1, -1), "A+W")
	Input.action_release("move_left")
	Input.action_release("move_up")
	Input.action_press("move_right")
	eq(InputReader.keyboard_vector(), Vector2(1, 0), "D")
	Input.action_release("move_right")
	eq(InputReader.keyboard_vector(), Vector2.ZERO, "solto")
	var j: PouJoystick = PouJoystick.new()
	j.start(Vector2.ZERO, Vector2(42, 0))
	Input.action_press("move_down")
	eq(InputReader.move_vector(j), Vector2(1, 0), "joystick tem prioridade")
	Input.action_release("move_down")
	check(InputMap.has_action("jump"), "acao jump existe")


func test_game_scene_runs() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var game: Node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	tree.root.add_child(game)
	var run: GameRun = game.get("run") as GameRun
	check(run != null and run.state == "playing", "run iniciada")
	game.call("_process", 1.0 / 60.0)
	game.call("_process", 1.0 / 60.0)
	var bear_view: Node2D = game.get("_bear_view") as Node2D
	check(bear_view != null, "BearView criado")
	bear_view.call("_process", 0.0)
	eq(bear_view.position, run.bear.pos, "view segue o modelo")
	eq((game.get("_ghost_views") as Dictionary).size(), 1, "1 view de fantasma")
	var lvl: Object = game.get("level")
	eq(run.level, lvl, "run.level = nivel da cena")
	run.bear.invuln = 100.0
	run.execute_biome_transition()
	check(run.level == game.get("level"), "transicao troca a cena de fase")
	eq(run.cycle.current_biome, 1, "bioma 2")
	for i in 9:
		run.execute_biome_transition()
		check(run.level == game.get("level"), "fase %d carregada" % (i + 2))
		var sp: Vector2i = run.level.call("bear_spawn_cell")
		check(not bool(run.level.call("is_wall", sp.x, sp.y)), "spawn livre na fase %d" % (i + 2))
	eq(run.cycle.current_biome, 0, "10 trocas voltam ao bioma 1")
	eq(run.cycle.cycle_count, 1, "ciclo 1")
	game.call("_process", 1.0 / 60.0)
	tree.root.remove_child(game)
	game.free()
