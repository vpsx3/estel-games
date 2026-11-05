class_name MechWindows
extends MechBase
## Janelas que espreitam (bioma 5). Porta mechInitWindows / mechUpdateWindows / mechDrawWindows.
## A janela vive em celula de PAREDE. Parametros por instancia (marcador "window"): -1 = usa cfg.

var windows: Array[Dictionary] = []   # {cell, armed, t, cd, radius, telegraph, cd_max}


func setup() -> void:
	var hand: Array = markers(["window"])
	if not hand.is_empty():
		for n in hand:
			windows.append(_make(marker_cell(n), _or_cfg(n.get("radius_cells"), "radius"),
				_or_cfg(n.get("telegraph"), "telegraph"), _or_cfg(n.get("cooldown"), "cd")))
		hide_markers(hand)
		return
	for r in range(1, Units.ROWS - 1):
		for c in range(1, Units.COLS - 1):
			if not wall(c, r):
				continue
			if run.rng.randf() < cfg_f("frac"):
				windows.append(_make(Vector2i(c, r), cfg_f("radius"), cfg_f("telegraph"), cfg_f("cd")))


func _or_cfg(v: Variant, key: String) -> float:
	return float(v) if v != null and float(v) >= 0.0 else cfg_f(key)


func _make(cell: Vector2i, radius: float, telegraph: float, cd_max: float) -> Dictionary:
	return {"cell": cell, "armed": false, "t": 0.0, "cd": 0.0, "radius": radius, "telegraph": telegraph, "cd_max": cd_max}


func update(r: GameRun, dt: float) -> void:
	for w in windows:
		if float(w["cd"]) > 0.0:
			w["cd"] = maxf(0.0, float(w["cd"]) - dt)
			w["armed"] = false
			w["t"] = 0.0
			continue
		var cell: Vector2i = w["cell"] as Vector2i
		var ctr: Vector2 = Units.cell_center(cell.x, cell.y)
		if ctr.distance_to(r.bear.pos) < float(w["radius"]) * Units.TILE:
			w["armed"] = true
			w["t"] = float(w["t"]) + dt
			if float(w["t"]) >= float(w["telegraph"]):   # telegrafou -> spawn de fantasma na janela
				r.ghost_sys.ghosts.append(r.ghost_sys.make_ghost("comum", ctr))
				w["t"] = 0.0
				w["armed"] = false
				w["cd"] = float(w["cd_max"])
		else:
			w["armed"] = false
			if float(w["t"]) > 0.0:
				w["t"] = maxf(0.0, float(w["t"]) - dt)


func draw_under(ci: CanvasItem) -> void:
	for w in windows:
		if not bool(w["armed"]):
			continue
		var cell: Vector2i = w["cell"] as Vector2i
		var p: float = minf(1.0, float(w["t"]) / float(w["telegraph"]))
		draw_slot(ci, "window_eyes", cell_rect(cell.x, cell.y), Color(1.0, 0.82, 0.31, 0.95), Color(1, 1, 1, 0.35 + 0.65 * p))
