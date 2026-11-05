extends "res://tests/case.gd"
## Loja de atributos: custos/niveis/efeitos (ATTR_DEFS), compra debitando o mel, persistencia,
## e efeito em jogo (velocidade, pulo cd/ext, pulo duplo). Isolada de Save (store injetado).

const F: GDScript = preload("res://tests/support/run_factory.gd")


func _shop(honey: int, attrs: Dictionary = {}) -> Shop:
	var store: Dictionary = Save.default_save()
	store["honey"] = honey
	for k: String in attrs:
		(store["attrs"] as Dictionary)[k] = attrs[k]
	return Shop.new(store, func() -> void: pass)


func test_defs_and_order() -> void:
	eq(Shop.order(), ["speed_base", "jump_cd", "jump_ext", "double_jump", "reroll"], "ATTR_ORDER")
	var s: Shop = _shop(0)
	eq(s.max_level("speed_base"), 10, "speed_base 10 niveis")
	eq(s.max_level("double_jump"), 1, "toggle 1 nivel")
	eq(s.next_cost("speed_base"), 50, "custo nivel 1")
	eq(s.next_cost("double_jump"), 2500, "pulo duplo 2500")
	eq(s.next_cost("reroll"), 3000, "reroll 3000")
	eq(s.next_value("speed_base"), 0.08, "+8%")
	eq(s.next_value("double_jump"), null, "toggle sem valor")
	eq(s.effect_text("speed_base"), "+8%", "texto velocidade")
	eq(s.effect_text("jump_cd"), "−10%", "texto cd")
	eq(s.effect_text("jump_ext"), "+0.09s", "texto pulo")
	eq(s.effect_text("reroll"), "", "toggle sem texto")


func test_buy_debits_honey_and_levels_up() -> void:
	var s: Shop = _shop(100)
	check(s.can_buy("speed_base"), "pode comprar (50)")
	check(s.buy("speed_base"), "compra")
	eq(s.honey(), 50, "debitou 50")
	eq(s.level("speed_base"), 1, "nivel 1")
	eq(s.next_cost("speed_base"), 80, "proximo custo 80")
	check(not s.buy("speed_base"), "50 < 80 => recusa")
	eq(s.honey(), 50, "mel intacto na recusa")
	eq(s.level("speed_base"), 1, "nivel intacto")
	eq(s.effect_text("speed_base"), "+16%", "proximo efeito")


func test_cost_curve_total_and_max() -> void:
	var s: Shop = _shop(100000)
	var total: int = 0
	var expected: Array = [50, 80, 120, 170, 230, 300, 400, 520, 680, 900]
	for i in 10:
		eq(s.next_cost("jump_cd"), expected[i], "custo nivel %d" % (i + 1))
		total += s.next_cost("jump_cd")
		check(s.buy("jump_cd"), "compra %d" % (i + 1))
	eq(total, 3450, "soma da curva")
	eq(s.honey(), 100000 - 3450, "mel final")
	check(s.is_maxed("jump_cd"), "no maximo")
	eq(s.next_cost("jump_cd"), -1, "sem proximo")
	check(not s.buy("jump_cd"), "nao passa do max")
	eq(s.level("jump_cd"), 10, "10")


func test_toggle_attrs_buy_once() -> void:
	var s: Shop = _shop(6000)
	check(s.buy("double_jump"), "pulo duplo")
	check(s.buy("reroll"), "reroll")
	eq(s.honey(), 6000 - 2500 - 3000, "debitos")
	check(not s.buy("double_jump"), "so uma vez")
	eq(s.level("double_jump"), 1, "nivel 1")


func test_persist_called_and_event() -> void:
	var calls: Array = []
	var store: Dictionary = Save.default_save()
	store["honey"] = 500
	var s: Shop = Shop.new(store, func() -> void: calls.append(1))
	var ev: Array = []
	var cb: Callable = func(id: String, lv: int) -> void: ev.append([id, lv])
	Events.attr_purchased.connect(cb)
	s.buy("jump_ext")
	Events.attr_purchased.disconnect(cb)
	eq(calls.size(), 1, "persistiu 1x")
	eq(ev, [["jump_ext", 1]], "Events.attr_purchased")
	eq(((store["attrs"] as Dictionary)["jump_ext"]), 1, "gravado no dicionario do save")
	eq(store["honey"], 450, "honey do save")


func test_levels_apply_in_run() -> void:
	var s: Shop = _shop(0, {"speed_base": 3, "jump_cd": 2, "jump_ext": 4, "double_jump": 1})
	var run: GameRun = GameRun.new(1)
	run.attr_levels = s.levels()
	run.start(F.open_level(0))
	near(run.bear.speed, run.bear.base_speed * (1.0 + 0.24), "speed_base nivel 3 = +24%", 0.0001)
	near(run.jump.cd_max, 10.0 * (1.0 - 0.16), "jump_cd nivel 2 = -16%", 0.0001)
	near(run.jump.duration, 0.55 + 0.36, "jump_ext nivel 4 = +0.36s", 0.0001)
	eq(run.jump.max_jumps(), 2, "pulo duplo")


func test_default_save_wiring() -> void:
	# Shop() sem argumentos usa o autoload Save (sem comprar nada, para nao tocar o save real)
	var s: Shop = Shop.new()
	eq(s.level("speed_base"), Save.attr_level("speed_base"), "le do Save")
	eq(s.honey(), Save.honey(), "mel do Save")
