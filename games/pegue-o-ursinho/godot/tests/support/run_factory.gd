extends RefCounted
## Helpers de teste do nucleo de gameplay (sem cena).

const FAKE: GDScript = preload("res://tests/support/fake_level.gd")


static func make_level(idx: int = 0) -> Node2D:
	var n: Node2D = Node2D.new()
	n.set_script(FAKE)
	n.call("setup", idx)
	return n


## Fase de teste totalmente aberta (interior livre, borda parede).
static func open_level(idx: int = 0) -> Node2D:
	var n: Node2D = make_level(idx)
	for r in range(1, 29):
		for c in range(1, 17):
			n.call("set_wall", c, r, false)
	return n


static func make_run(seed_value: int = 1, open: bool = true, idx: int = 0) -> GameRun:
	var run: GameRun = GameRun.new(seed_value)
	run.level_loader = func(i: int) -> Object: return open_level(i) if open else make_level(i)
	run.start(open_level(idx) if open else make_level(idx))
	return run


## Passos de 1/60 s; protect=true mantem o urso invulneravel (simula tempo sem game over).
static func advance(run: GameRun, seconds: float, input: Vector2 = Vector2.ZERO, protect: bool = false) -> void:
	var n: int = int(round(seconds * 60.0))
	for i in n:
		if protect:
			run.bear.invuln = 100.0
		run.step(1.0 / 60.0, input)


## Run completa (E4b): mecanicas + buffs ligados. Sem selecao pre-run (reset_run_state direto).
static func make_full(seed_value: int = 1, idx: int = 0, open: bool = true) -> GameRun:
	var run: GameRun = GameRun.new(seed_value)
	run.level_loader = func(i: int) -> Object: return open_level(i) if open else make_level(i)
	MechFactory.install(run)
	var b: BuffSystem = BuffSystem.new(run)
	b.attach()
	run.start(open_level(idx) if open else make_level(idx))
	b.reset_run_state()
	return run


## Run iniciada na fase `idx` (mapa original ou aberto) com a mecanica daquele bioma montada.
## `nodes` = marcadores colocados a mao (fake_level.mech_nodes).
static func make_mech_run(idx: int, open: bool = false, seed_value: int = 1, nodes: Array = []) -> GameRun:
	var lvl: Node2D = open_level(idx) if open else make_level(idx)
	lvl.set("mech_nodes", nodes)
	var run: GameRun = GameRun.new(seed_value)
	run.start(lvl)
	run.mech = MechFactory.create(run, idx) as Object
	return run


static func marker(kind: String, cell: Vector2i, props: Dictionary = {}) -> Node2D:
	var m: Node2D = MechMarker.new()
	m.set("kind", kind)
	m.position = Units.cell_center(cell.x, cell.y)
	for k: String in props:
		m.set(k, props[k])
	return m
