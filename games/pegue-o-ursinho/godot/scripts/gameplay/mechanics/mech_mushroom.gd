class_name MechMushroom
extends MechBase
## Cogumelo-trampolim (bioma 0). Porta mechInitMushroom / mechUpdateMushroom / mechDrawMushroom.

var mushrooms: Array[Dictionary] = []   # {cell: Vector2i, dist: int}
var fired: Dictionary = {}              # Vector2i -> elapsed do ultimo disparo


func setup() -> void:
	var hand: Array = markers(["mushroom"])
	if not hand.is_empty():
		for n in hand:
			var d: int = int(n.get("dist"))
			mushrooms.append({"cell": marker_cell(n), "dist": d if d >= 0 else int(cfg_f("dist"))})
		hide_markers(hand)
		return
	var sp: Vector2i = run.level.call("bear_spawn_cell") as Vector2i
	var spc: Vector2 = Units.cell_center(sp.x, sp.y)
	var cells: Array = []
	for cell in GridCollision.free_cells(run.level):
		if Units.cell_center(cell.x, cell.y).distance_to(spc) > Units.TILE * GameplayLits.MUSH_MIN_SPAWN_CELLS:
			cells.append(cell)
	for cell: Vector2i in pick_random(cells, int(cfg_f("count"))):
		mushrooms.append({"cell": cell, "dist": int(cfg_f("dist"))})


func update(r: GameRun, dt: float) -> void:
	var bear: BearModel = r.bear
	if bear.mush_cd > 0.0:
		bear.mush_cd -= dt
		if bear.mush_cd < 0.0:
			bear.mush_cd = 0.0
	if bear.mush_cd > 0.0 or bear.landing_target != null:
		return
	var bc: Vector2i = bear_cell()
	var m: Dictionary = {}
	for mm in mushrooms:
		if mm["cell"] == bc:
			m = mm
			break
	if m.is_empty():
		return
	var dc: int = 0
	var dr: int = 0
	if bear.facing == "east":
		dc = 1
	elif bear.facing == "west":
		dc = -1
	elif bear.facing == "north":
		dr = -1
	else:
		dr = 1
	var dest: Vector2i = bc
	for step in range(1, int(m["dist"]) + 1):
		var nc: int = bc.x + dc * step
		var nr: int = bc.y + dr * step
		if nr < 0 or nr >= Units.ROWS or nc < 0 or nc >= Units.COLS or wall(nc, nr):
			break   # para 1 tile antes da parede
		dest = Vector2i(nc, nr)
	bear.glide_to(Units.cell_center(dest.x, dest.y))
	bear.mush_cd = cfg_f("cd")
	fired[bc] = r.elapsed


func draw_under(ci: CanvasItem) -> void:
	for m in mushrooms:
		var cell: Vector2i = m["cell"] as Vector2i
		var h: float = float(tile_hash(cell.y, cell.x) % 628) / 100.0
		var bob: float = sin(run.elapsed * 4.0 + h) * Units.px(2.0)
		var sy: float = 1.0
		if fired.has(cell):
			var since: float = run.elapsed - float(fired[cell])
			if since < GameplayLits.MUSH_SQUASH_TIME:
				sy = 0.6 + 0.4 * (since / GameplayLits.MUSH_SQUASH_TIME)
		var ctr: Vector2 = Units.cell_center(cell.x, cell.y) + Vector2(0, bob)
		ci.draw_set_transform(ctr, 0.0, Vector2(1.0, sy))
		draw_slot(ci, "mushroom", Rect2(-Units.TILE / 2.0, -Units.TILE / 2.0, Units.TILE, Units.TILE), Color(0.86, 0.31, 0.31, 0.9))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
