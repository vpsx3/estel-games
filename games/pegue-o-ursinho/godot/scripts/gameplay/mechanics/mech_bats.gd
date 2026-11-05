class_name MechBats
extends MechBase
## Morcegos que travam o urso (bioma 4). Porta mechInitBats / mechSpawnBat / mechUpdateBats /
## mechDrawBats. Velocidade: cfg.speed (px/frame legado) -> px/s por Units; raio cfg.r -> Units.px.
## Hand-placed: marcadores "bat_spawn" viram pontos de entrada (angulo aleatorio).

var bats: Array[Dictionary] = []   # {pos, vel (px/s), frame, ft, hit}
var bat_timer: float = 0.0
var _spawns: Array = []


func setup() -> void:
	bat_timer = cfg_f("interval")
	_spawns = markers(["bat_spawn"])
	hide_markers(_spawns)


func spawn_bat() -> void:
	var spread: float = GameplayLits.BAT_ANGLE_SPREAD
	var margin: float = Units.px(GameplayLits.BAT_SPAWN_MARGIN)
	var pos: Vector2
	var ang: float
	if not _spawns.is_empty():
		var n: Node2D = _spawns[int(run.rng.randf() * _spawns.size())] as Node2D
		pos = n.position
		if n.is_inside_tree() and run.level is Node2D:
			pos = n.global_position - (run.level as Node2D).global_position
		ang = run.rng.randf() * TAU
	else:
		var side: int = int(run.rng.randf() * 4.0)
		if side == 0:
			pos = Vector2(-margin, run.rng.randf() * Units.WORLD_H)
			ang = -spread + run.rng.randf() * spread * 2.0
		elif side == 1:
			pos = Vector2(Units.WORLD_W + margin, run.rng.randf() * Units.WORLD_H)
			ang = PI + (-spread + run.rng.randf() * spread * 2.0)
		elif side == 2:
			pos = Vector2(run.rng.randf() * Units.WORLD_W, -margin)
			ang = PI / 2.0 + (-spread + run.rng.randf() * spread * 2.0)
		else:
			pos = Vector2(run.rng.randf() * Units.WORLD_W, Units.WORLD_H + margin)
			ang = -PI / 2.0 + (-spread + run.rng.randf() * spread * 2.0)
	var spd: float = Units.speed_px_frame_to_px_s(cfg_f("speed"))
	bats.append({"pos": pos, "vel": Vector2(cos(ang), sin(ang)) * spd, "frame": 0, "ft": 0.0, "hit": false})


func update(r: GameRun, dt: float) -> void:
	bat_timer -= dt
	if bat_timer <= 0.0:
		spawn_bat()
		bat_timer = cfg_f("interval")
	var cull: float = Units.px(GameplayLits.BAT_CULL_MARGIN)
	for i in range(bats.size() - 1, -1, -1):
		var b: Dictionary = bats[i]
		var p: Vector2 = (b["pos"] as Vector2) + (b["vel"] as Vector2) * dt
		b["pos"] = p
		b["ft"] = float(b["ft"]) + dt
		if float(b["ft"]) >= GameplayLits.BAT_FRAME_TIME:
			b["ft"] = 0.0
			b["frame"] = 0 if int(b["frame"]) != 0 else 1
		if p.x < -cull or p.x > Units.WORLD_W + cull or p.y < -cull or p.y > Units.WORLD_H + cull:
			bats.remove_at(i)
			continue
		if not bool(b["hit"]) and p.distance_to(r.bear.pos) < r.bear.size + Units.px(cfg_f("r")):
			b["hit"] = true   # trava o urso, nao mata
			r.bear.frozen = maxf(r.bear.frozen, cfg_f("freeze"))
			r.notify(I18n.t("notif_bat"), "#c9b3ff", r.bear.pos - Vector2(0, Units.px(28.0)))


func draw_over(ci: CanvasItem) -> void:
	var sz: float = Units.px(34.0)
	var sheet: Texture2D = tex("bat_sheet")
	for b in bats:
		var p: Vector2 = b["pos"] as Vector2
		ci.draw_circle(p, sz * 0.9, Color(0.78, 0.67, 1.0, 0.25))   # halo
		var flip: float = -1.0 if (b["vel"] as Vector2).x < 0.0 else 1.0
		ci.draw_set_transform(p, 0.0, Vector2(flip, 1.0))
		if sheet != null:
			ci.draw_texture_rect_region(sheet, Rect2(-sz / 2.0, -sz / 2.0, sz, sz), Rect2(int(b["frame"]) * 144, 0, 144, 144))
		else:
			ci.draw_circle(Vector2.ZERO, sz * 0.4, Color("6a5a8a"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
