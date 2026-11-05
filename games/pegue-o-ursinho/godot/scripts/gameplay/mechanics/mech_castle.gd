class_name MechCastle
extends MechBase
## Castelo: grades + tapete (bioma 6). Porta mechInitCastle / mechUpdateCastle / mechDrawCastle,
## blocks_bear (grade fechada) e mechSpeedMult (tapete). gates e carpet sao independentes: cada
## um usa os marcadores ("gate" / "carpet") se existirem, senao e procedural.

var gates: Array[Dictionary] = []   # {cell, phase, cl}
var carpet: Dictionary = {}         # Vector2i -> true


func _is_wall_or_out(c: int, r: int) -> bool:
	return r < 0 or r >= Units.ROWS or c < 0 or c >= Units.COLS or wall(c, r)


func setup() -> void:
	var hand_gates: Array = markers(["gate"])
	if not hand_gates.is_empty():
		for n in hand_gates:
			var cell: Vector2i = marker_cell(n)
			var ph: float = float(n.get("phase"))
			gates.append({"cell": cell, "phase": ph if ph >= 0.0 else float((cell.y + cell.x) % 2) * PI, "cl": -1.0})
		hide_markers(hand_gates)
	else:
		for r in range(1, Units.ROWS - 1):
			for c in range(1, Units.COLS - 1):
				if wall(c, r):
					continue
				var corridor: bool = (_is_wall_or_out(c, r - 1) and _is_wall_or_out(c, r + 1)) \
					or (_is_wall_or_out(c - 1, r) and _is_wall_or_out(c + 1, r))
				if corridor and run.rng.randf() < cfg_f("gateFrac"):
					gates.append({"cell": Vector2i(c, r), "phase": float((r + c) % 2) * PI, "cl": -1.0})
	var hand_carpet: Array = markers(["carpet"])
	if not hand_carpet.is_empty():
		for n in hand_carpet:
			var start: Vector2i = marker_cell(n)
			for k in maxi(1, int(n.get("length_cells"))):
				var cc: Vector2i = Vector2i(start.x + k, start.y)
				if not _is_wall_or_out(cc.x, cc.y):
					carpet[cc] = true
		hide_markers(hand_carpet)
		return
	var floor_rows: Array = []
	for r in range(1, Units.ROWS - 1):
		for c in range(1, Units.COLS - 1):
			if not wall(c, r):
				floor_rows.append(r)
				break
	for r: int in pick_random(floor_rows, int(cfg_f("carpetRows"))):
		for c in range(1, Units.COLS - 1):
			if not wall(c, r):
				carpet[Vector2i(c, r)] = true


func update(r: GameRun, _dt: float) -> void:
	var bc: Vector2i = bear_cell()
	for g in gates:
		var s: float = sin(r.elapsed * cfg_f("gateSpeed") + float(g["phase"]))
		if (g["cell"] as Vector2i) == bc:
			s = -1.0   # grade ocupada pelo urso nao fecha (fairness)
		g["cl"] = s   # -1..1 ; > 0 fechando


func blocks_bear(x: float, y: float) -> bool:
	var cell: Vector2i = Units.world_to_cell(Vector2(x, y))
	for g in gates:
		if (g["cell"] as Vector2i) == cell:
			return float(g["cl"]) > GameplayLits.CASTLE_CLOSED_THRESHOLD
	return false


func speed_mult(r: GameRun) -> float:
	if carpet.has(Units.world_to_cell(r.bear.pos)):
		return cfg_f("carpetBoost")
	return 1.0


func draw_under(ci: CanvasItem) -> void:
	for cell: Vector2i in carpet:   # tapete primeiro (grade por cima)
		draw_slot(ci, "carpet", cell_rect(cell.x, cell.y), Color(0.67, 0.16, 0.16, 0.5))
	for g in gates:
		var cl: float = maxf(0.0, float(g["cl"]))
		if cl <= 0.02:
			continue   # aberta: barras recolhidas
		var cell: Vector2i = g["cell"] as Vector2i
		ci.draw_set_transform(Vector2(cell.x * Units.TILE, cell.y * Units.TILE), 0.0, Vector2(1.0, maxf(0.05, cl)))
		draw_slot(ci, "gate", Rect2(0, 0, Units.TILE, Units.TILE), Color(0.75, 0.67, 0.35, 0.92), Color(1, 1, 1, 0.25 + 0.75 * cl))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
