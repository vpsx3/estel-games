class_name MechSky
extends MechBase
## Ilhas Flutuantes: plataformas moveis + correntes de ar (bioma 7). Porta mechInitSky /
## mechUpdateSky / mechApplyDrift / mechDrawSky. platforms e winds sao independentes: cada um usa
## os marcadores ("platform" / "wind") se existirem, senao e procedural.
## Plataforma = celula BLOQUEADA ao urso que desliza (axis h/v, +-range celulas).

var platforms: Array[Dictionary] = []   # {r0, c0, axis, phase, range, off, cont, r, c}
var winds: Dictionary = {}              # Vector2i -> Vector2 (direcao)


func setup() -> void:
	var hand_plat: Array = markers(["platform"])
	if not hand_plat.is_empty():
		for n in hand_plat:
			var cell: Vector2i = marker_cell(n)
			var rg: int = int(n.get("range_cells"))
			var ph: float = float(n.get("phase"))
			platforms.append(_make_platform(cell.y, cell.x, str(n.get("axis")),
				ph if ph >= 0.0 else run.rng.randf() * TAU, rg if rg >= 0 else int(cfg_f("platRange"))))
		hide_markers(hand_plat)
	else:
		_procedural_platforms()
	var hand_wind: Array = markers(["wind"])
	if not hand_wind.is_empty():
		for n in hand_wind:
			var start: Vector2i = marker_cell(n)
			var dir: Vector2i = n.get("wind_dir") as Vector2i
			if dir == Vector2i.ZERO:
				dir = Vector2i.RIGHT
			for k in maxi(1, int(n.get("length_cells"))):
				var cc: Vector2i = start + dir * k
				if cc.x >= 0 and cc.x < Units.COLS and cc.y >= 0 and cc.y < Units.ROWS and not wall(cc.x, cc.y):
					winds[cc] = Vector2(dir)
		hide_markers(hand_wind)
	else:
		_procedural_winds()


func _make_platform(r0: int, c0: int, axis: String, phase: float, rg: int) -> Dictionary:
	return {"r0": r0, "c0": c0, "axis": axis, "phase": phase, "range": rg, "off": 0, "cont": 0.0, "r": r0, "c": c0}


func _procedural_platforms() -> void:
	var rg: int = int(cfg_f("platRange"))
	var cells: Array = pick_random(GridCollision.free_cells(run.level), 9999)   # embaralha candidatas
	for cell: Vector2i in cells:
		if platforms.size() >= int(cfg_f("platforms")):
			break
		var axis: String = "h" if run.rng.randf() < 0.5 else "v"
		var ok: bool = true
		for o in range(-rg, rg + 1):
			var rr: int = cell.y + (o if axis == "v" else 0)
			var cc: int = cell.x + (o if axis == "h" else 0)
			if rr < 1 or rr >= Units.ROWS - 1 or cc < 1 or cc >= Units.COLS - 1 or wall(cc, rr):
				ok = false
				break
		if not ok:
			continue
		var near_other: bool = false
		for p in platforms:
			if absi(int(p["r0"]) - cell.y) + absi(int(p["c0"]) - cell.x) < 3:   # espaca
				near_other = true
				break
		if near_other:
			continue
		platforms.append(_make_platform(cell.y, cell.x, axis, run.rng.randf() * TAU, rg))


func _procedural_winds() -> void:
	for i in GameplayLits.SKY_WIND_BANDS:
		if run.rng.randf() < 0.5:
			var r: int = 1 + int(run.rng.randf() * (Units.ROWS - 2))
			var dir: Vector2 = Vector2(1.0 if run.rng.randf() < 0.5 else -1.0, 0.0)
			for c in range(1, Units.COLS - 1):
				if not wall(c, r):
					winds[Vector2i(c, r)] = dir
		else:
			var c2: int = 1 + int(run.rng.randf() * (Units.COLS - 2))
			var dir2: Vector2 = Vector2(0.0, 1.0 if run.rng.randf() < 0.5 else -1.0)
			for r2 in range(1, Units.ROWS - 1):
				if not wall(c2, r2):
					winds[Vector2i(c2, r2)] = dir2


func update(r: GameRun, _dt: float) -> void:
	for p in platforms:
		var cont: float = sin(r.elapsed * cfg_f("platSpeed") + float(p["phase"])) * float(p["range"])
		p["cont"] = cont
		var off: int = floori(cont + 0.5)   # Math.round do JS
		p["off"] = off
		p["r"] = int(p["r0"]) + (off if str(p["axis"]) == "v" else 0)
		p["c"] = int(p["c0"]) + (off if str(p["axis"]) == "h" else 0)
	var bc: Vector2i = bear_cell()
	for p in platforms:   # plataforma alcancou o urso -> empurra
		if int(p["r"]) == bc.y and int(p["c"]) == bc.x and r.bear.landing_target == null:
			var blocked: Dictionary = {}
			for q in platforms:
				blocked[Vector2i(int(q["c"]), int(q["r"]))] = true
			push_to_dry(blocked)
			break


func blocks_bear(x: float, y: float) -> bool:
	var cell: Vector2i = Units.world_to_cell(Vector2(x, y))
	for p in platforms:
		if int(p["r"]) == cell.y and int(p["c"]) == cell.x:
			return true
	return false


func apply_drift(r: GameRun, dt: float) -> void:
	var dir: Variant = winds.get(bear_cell())
	if dir == null:
		return
	var f: float = Units.speed_px_frame_to_px_s(cfg_f("windForce")) * dt
	var d: Vector2 = dir as Vector2
	var bear: BearModel = r.bear
	var nx: float = bear.pos.x + d.x * f
	var ny: float = bear.pos.y + d.y * f
	if GridCollision.can_move(r.level, nx, bear.pos.y, bear.size) and not blocks_bear(nx, bear.pos.y):
		bear.pos.x = nx
	if GridCollision.can_move(r.level, bear.pos.x, ny, bear.size) and not blocks_bear(bear.pos.x, ny):
		bear.pos.y = ny


func draw_under(ci: CanvasItem) -> void:
	var a: float = 0.22 + 0.08 * sin(run.elapsed * 3.0)
	for cell: Vector2i in winds:   # correntes (sob plataformas)
		var d: Vector2 = winds[cell] as Vector2
		ci.draw_set_transform(Units.cell_center(cell.x, cell.y), d.angle(), Vector2.ONE)
		draw_slot(ci, "wind", Rect2(-Units.TILE / 2.0, -Units.TILE / 2.0, Units.TILE, Units.TILE), Color(0.78, 0.9, 1.0, 0.7), Color(1, 1, 1, a))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for p in platforms:   # posicao sub-tile interpolada (desliza suave)
		var x: float = (float(p["c0"]) + (float(p["cont"]) if str(p["axis"]) == "h" else 0.0)) * Units.TILE
		var y: float = (float(p["r0"]) + (float(p["cont"]) if str(p["axis"]) == "v" else 0.0)) * Units.TILE
		draw_slot(ci, "platform", Rect2(x, y, Units.TILE, Units.TILE), Color(0.59, 0.71, 0.82, 0.92))
