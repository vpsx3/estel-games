class_name MechFire
extends MechBase
## Inferno: geiseres + rastro de fogo (bioma 8). Porta mechInitFire / mechGeyserState /
## mechUpdateFire / mechDrawFireUnder / mechDrawFireOver. Geiser nunca mata: empurra e da invuln.

var geysers: Array[Dictionary] = []   # {cell, phase}
var trail: Array[Dictionary] = []     # {pos, life}
var trail_timer: float = 0.0


func setup() -> void:
	var hand: Array = markers(["geyser"])
	if not hand.is_empty():
		for n in hand:
			var ph: float = float(n.get("phase"))
			geysers.append({"cell": marker_cell(n), "phase": ph if ph >= 0.0 else run.rng.randf() * TAU})
		hide_markers(hand)
		return
	var sp: Vector2i = run.level.call("bear_spawn_cell") as Vector2i
	var cells: Array = []
	for cell in GridCollision.free_cells(run.level):
		if absi(cell.y - sp.y) + absi(cell.x - sp.x) > 2:
			cells.append(cell)
	for cell: Vector2i in pick_random(cells, int(cfg_f("geyserCount"))):
		geysers.append({"cell": cell, "phase": run.rng.randf() * TAU})


func geyser_state(g: Dictionary) -> String:
	var s: float = sin(run.elapsed * cfg_f("geySpeed") + float(g["phase"]))
	if s > GameplayLits.GEYSER_FIRE_AT:
		return "fire"
	return "warming" if s > GameplayLits.GEYSER_WARM_AT else "idle"


func update(r: GameRun, dt: float) -> void:
	var bear: BearModel = r.bear
	var bc: Vector2i = bear_cell()
	for g in geysers:
		if (g["cell"] as Vector2i) == bc and geyser_state(g) == "fire":   # empurra + invuln; nunca mata
			if bear.landing_target == null:
				var blocked: Dictionary = {}
				for gg in geysers:
					if geyser_state(gg) == "fire":
						blocked[gg["cell"]] = true
				push_to_dry(blocked)
			bear.invuln = maxf(bear.invuln, GameplayLits.GEYSER_INVULN)
	trail_timer -= dt
	if bear.moving and trail_timer <= 0.0:
		trail.append({"pos": bear.pos, "life": cfg_f("trailLife")})
		trail_timer = cfg_f("trailDrop")
	for i in range(trail.size() - 1, -1, -1):
		var t: Dictionary = trail[i]
		t["life"] = float(t["life"]) - dt
		if float(t["life"]) <= 0.0:
			trail.remove_at(i)
			continue
		for gh in r.ghost_sys.ghosts:
			if gh.pos.distance_to(t["pos"] as Vector2) < Units.TILE * GameplayLits.TRAIL_HIT_CELLS:
				r.ghost_sys.push_ghost(gh)   # empurra e atordoa
				gh.frozen = maxf(gh.frozen, cfg_f("trailFreeze"))


func draw_under(ci: CanvasItem) -> void:
	for t in trail:
		var a: float = float(t["life"]) / cfg_f("trailLife")
		draw_tex(ci, frame_at("fire_trail", "default", run.elapsed + (t["pos"] as Vector2).x * 0.02), t["pos"] as Vector2,
			Color(1.0, 0.47, 0.16, 0.7), Color(1, 1, 1, a), Vector2(Units.TILE * 0.8, Units.TILE * 0.8))
	for g in geysers:
		var cell: Vector2i = g["cell"] as Vector2i
		var al: float = 1.0
		if geyser_state(g) == "warming":
			al = 0.7 + 0.3 * sin(run.elapsed * 20.0)   # shimmer telegrafa antes do fogo
		draw_tex(ci, frame_at("geyser", "idle", run.elapsed + float(g["phase"])), Units.cell_center(cell.x, cell.y),
			Color(0.47, 0.24, 0.16, 0.85), Color(1, 1, 1, al))


## Progresso 0..1 da janela de fogo do geiser (sin(theta) > GEYSER_FIRE_AT).
func fire_progress(g: Dictionary) -> float:
	var th: float = fposmod(run.elapsed * cfg_f("geySpeed") + float(g["phase"]), TAU)
	var a: float = asin(GameplayLits.GEYSER_FIRE_AT)
	return clampf((th - a) / (PI - 2.0 * a), 0.0, 1.0)


func draw_over(ci: CanvasItem) -> void:
	for g in geysers:
		if geyser_state(g) != "fire":
			continue
		var cell: Vector2i = g["cell"] as Vector2i
		draw_tex(ci, frame_p("geyser", "fire", fire_progress(g)), Units.cell_center(cell.x, cell.y),
			Color(1.0, 0.47, 0.12, 0.9))
