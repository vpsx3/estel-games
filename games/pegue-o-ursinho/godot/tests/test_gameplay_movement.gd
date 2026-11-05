extends "res://tests/case.gd"
## Urso: movimento + colisao por celula (moveBear/canMove/tileAt/dirFromVec).

const F: GDScript = preload("res://tests/support/run_factory.gd")


func _speed() -> float:
	return Units.speed_px_frame_to_px_s(3.3 * 0.5)


func test_dir_from_vec() -> void:
	eq(BearModel.dir_from_vec(1, 0.2), "east", "east")
	eq(BearModel.dir_from_vec(-1, 0.2), "west", "west")
	eq(BearModel.dir_from_vec(0.2, 1), "south", "south")
	eq(BearModel.dir_from_vec(0.2, -1), "north", "north")
	eq(BearModel.dir_from_vec(0, 0, "west"), "west", "parado mantem")
	eq(BearModel.dir_from_vec(1, 1), "south", "empate vai para vertical")


func test_grid_collision() -> void:
	var lv: Node2D = F.make_level(0)
	check(GridCollision.is_blocked_at(lv, -1, 10), "fora = parede")
	check(GridCollision.is_blocked_at(lv, 5, 5), "borda = parede")
	var sp: Vector2i = lv.call("bear_spawn_cell")
	var ctr: Vector2 = Units.cell_center(sp.x, sp.y)
	check(GridCollision.can_move(lv, ctr.x, ctr.y, Units.px(14)), "spawn do urso cabe")
	check(not GridCollision.can_move(lv, 8.0, 8.0, Units.px(14)), "quina em parede nao cabe")
	var cells: Array[Vector2i] = GridCollision.free_cells(lv)
	var expected: int = 0
	for r in range(1, 29):
		for c in range(1, 17):
			if int(GameState.maps[0][r][c]) == 0:
				expected += 1
	eq(cells.size(), expected, "freeCells conta so interior livre")
	lv.free()


func test_speed_conversion_straight() -> void:
	var run: GameRun = F.make_run()
	var x0: float = run.bear.pos.x
	for i in 60:
		run.bear.move(run, 1.0 / 60.0, Vector2.RIGHT)
	near(run.bear.pos.x - x0, _speed(), "1s a 3.3*0.5 px/frame@60 convertidos", 0.01)
	near(_speed(), 1.65 * 60.0 * 32.0 / 36.0, "px/s = legado*60*TILE_SCALE")
	eq(run.bear.facing, "east", "facing east")
	check(run.bear.moving, "moving")


func test_diagonal_normalized_and_partial_stick() -> void:
	var run: GameRun = F.make_run()
	var p0: Vector2 = run.bear.pos
	for i in 30:
		run.bear.move(run, 1.0 / 60.0, Vector2(1, 1))
	near(run.bear.pos.distance_to(p0), _speed() * 0.5, "diagonal normalizada", 0.01)
	run = F.make_run()
	p0 = run.bear.pos
	for i in 60:
		run.bear.move(run, 1.0 / 60.0, Vector2(0.5, 0))
	near(run.bear.pos.x - p0.x, _speed() * 0.5, "joystick parcial = metade", 0.01)


func test_wall_blocks_and_never_enters() -> void:
	var run: GameRun = F.make_run()
	run.level.call("set_wall", 10, 14, true)
	for i in 240:
		run.bear.move(run, 1.0 / 60.0, Vector2.RIGHT)
	check(GridCollision.can_move(run.level, run.bear.pos.x, run.bear.pos.y, run.bear.size), "urso nunca fica em parede")
	check(run.bear.pos.x < 10 * 32.0, "parou antes da parede")
	check(run.bear.pos.x > 9.5 * 32.0, "encostou na parede")


func test_world_clamp_and_poison_and_frozen() -> void:
	var run: GameRun = F.make_run()
	run.bear.pos = Vector2(40, 40)
	run.jump.active = true   # fase: atravessa paredes, mas fica dentro do mundo
	for i in 300:
		run.bear.move(run, 1.0 / 60.0, Vector2(-1, -1))
	# JS: so anda se nx > size; para a menos de um passo da borda e nunca sai do mundo
	var step: float = Units.speed_px_frame_to_px_s(3.3 * 0.5) / 60.0
	check(run.bear.pos.x >= run.bear.size and run.bear.pos.x < run.bear.size + step, "x preso na borda do mundo")
	check(run.bear.pos.y >= run.bear.size and run.bear.pos.y < run.bear.size + step, "y preso na borda do mundo")
	run = F.make_run()
	run.bear.poisoned = true
	var x0: float = run.bear.pos.x
	for i in 60:
		run.bear.move(run, 1.0 / 60.0, Vector2.RIGHT)
	near(run.bear.pos.x - x0, _speed() * 0.6, "veneno POISON_DEBUFF 0.6", 0.01)
	run = F.make_run()
	run.bear.frozen = 1.0
	x0 = run.bear.pos.x
	run.bear.move(run, 0.1, Vector2.RIGHT)
	eq(run.bear.pos.x, x0, "congelado nao anda")


func test_jump_phasing_through_wall() -> void:
	var run: GameRun = F.make_run()
	run.level.call("set_wall", 10, 14, true)
	run.jump.active = true
	run.jump.timer = 5.0
	for i in 60:
		run.bear.move(run, 1.0 / 60.0, Vector2.RIGHT)
	check(run.bear.pos.x > 10 * 32.0, "pulo atravessa parede")


func test_buff_hooks_multiply_speed() -> void:
	var run: GameRun = F.make_run()
	run.bear_boost_timer = 4.0
	run.bear_boost_mult = 1.8
	var x0: float = run.bear.pos.x
	for i in 30:
		run.bear.move(run, 1.0 / 60.0, Vector2.RIGHT)
	near(run.bear.pos.x - x0, _speed() * 0.5 * 1.8, "gancho bear_boost", 0.01)
	run = F.make_run()
	run.attr_levels = {"speed_base": 5}
	run.recalc_passives()
	near(run.bear.speed, 3.3 * 0.5 * 1.4, "atributo speed_base nivel 5 = +40%")
