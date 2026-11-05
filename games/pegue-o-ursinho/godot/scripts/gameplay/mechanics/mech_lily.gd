class_name MechLily
extends MechBase
## Vitoria-regia que afunda (bioma 3). Porta mechInitLily / mechUpdateLily / mechDrawLily.
## lilies: Vector2i -> {state: "stable"|"sinking"|"gone", t: float}.

var lilies: Dictionary = {}


func setup() -> void:
	var hand: Array = markers(["lilypad"])
	if not hand.is_empty():
		for n in hand:
			lilies[marker_cell(n)] = {"state": "stable", "t": 0.0}
		hide_markers(hand)
		return
	for r in range(1, Units.ROWS - 1):
		for c in range(1, Units.COLS - 1):
			if wall(c, r):
				continue
			if run.rng.randf() < cfg_f("frac"):
				lilies[Vector2i(c, r)] = {"state": "stable", "t": 0.0}


func gone_set() -> Dictionary:
	var s: Dictionary = {}
	for k: Vector2i in lilies:
		if str((lilies[k] as Dictionary)["state"]) == "gone":
			s[k] = true
	return s


func blocks_bear(x: float, y: float) -> bool:
	var l: Variant = lilies.get(Units.world_to_cell(Vector2(x, y)))
	return l != null and str((l as Dictionary)["state"]) == "gone"


func update(r: GameRun, dt: float) -> void:
	var on_key: Vector2i = bear_cell()
	for key: Vector2i in lilies:
		var l: Dictionary = lilies[key]
		var st: String = str(l["state"])
		if st == "stable":
			if key == on_key:   # so afunda quando o urso pisa (evita encurralar)
				l["state"] = "sinking"
				l["t"] = cfg_f("sinkDelay")
		elif st == "sinking":
			l["t"] = float(l["t"]) - dt
			if float(l["t"]) <= 0.0:
				l["state"] = "gone"
				l["t"] = cfg_f("gone")
				if key == on_key and r.bear.landing_target == null:
					push_to_dry(gone_set())
		else:   # gone
			l["t"] = float(l["t"]) - dt
			if float(l["t"]) <= 0.0:
				l["state"] = "stable"
				l["t"] = 0.0


func draw_under(ci: CanvasItem) -> void:
	for key: Vector2i in lilies:
		var l: Dictionary = lilies[key]
		var st: String = str(l["state"])
		if st == "gone":
			continue
		var ctr: Vector2 = Units.cell_center(key.x, key.y)
		var rect: Rect2 = Rect2(-Units.TILE / 2.0, -Units.TILE / 2.0, Units.TILE, Units.TILE)
		if st == "stable":
			ci.draw_set_transform(ctr, 0.0, Vector2.ONE)
			draw_slot(ci, "lilypad", rect, Color(0.24, 0.59, 0.27, 0.9))
		else:   # sinking: tremor/tilt proporcional ao progresso
			var prog: float = 1.0 - float(l["t"]) / cfg_f("sinkDelay")
			var tilt: float = sin(run.elapsed * 30.0) * 0.12 * prog
			ci.draw_set_transform(ctr, tilt, Vector2(1.0, 1.0 - 0.25 * prog))
			draw_slot(ci, "lilypad_sink", rect, Color(0.2, 0.47, 0.24, 0.8), Color(1, 1, 1, 1.0 - 0.3 * prog))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
