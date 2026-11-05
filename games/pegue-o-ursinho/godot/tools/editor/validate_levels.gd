@tool
extends SceneTree
## Validador das fases (HANDOFF 7.3).
## Headless: "$GODOT_PATH" --headless --path <projeto> --script res://tools/editor/validate_levels.gd
## Editor: botao "Validar fase" no LevelRoot. API: validate(level) -> {errors: Array, warnings: Array}.
## Regras de erro: borda aberta, spawn em parede/fora, distancia urso-fantasma < config.min_spawn_dist,
## celula livre nao conectada (flood-fill), mecanica em parede, densidade fora da meta +-tolerancia
## (vira AVISO se level.edicao_manual). Avisos: area livre < config.min_free_cells.


static func validate(level: LevelRoot) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cols: int = LevelRoot.COLS
	var rows: int = LevelRoot.ROWS
	var cfg: BiomeConfig = level.config
	if cfg == null:
		errors.append("config (BiomeConfig) ausente")
		return {"errors": errors, "warnings": warnings}

	# borda
	var open_border: Array[String] = []
	for r in rows:
		for c in cols:
			if (r == 0 or c == 0 or r == rows - 1 or c == cols - 1) and not level.is_wall(c, r):
				open_border.append("(%d,%d)" % [c, r])
	if not open_border.is_empty():
		errors.append("borda aberta em %d celula(s): %s" % [open_border.size(), ", ".join(open_border.slice(0, 5))])

	# spawns
	var bear: Vector2i = level.bear_spawn_cell()
	var ghost: Vector2i = level.ghost_spawn_cell()
	var spawns_ok: bool = true
	for pair: Array in [["SpawnUrso", bear], ["SpawnFantasma", ghost]]:
		var cell: Vector2i = pair[1] as Vector2i
		if cell.x < 0 or cell.y < 0 or cell.x >= cols or cell.y >= rows:
			errors.append("%s fora do mapa %s" % [pair[0], str(cell)])
			spawns_ok = false
		elif level.is_wall(cell.x, cell.y):
			errors.append("%s em parede %s" % [pair[0], str(cell)])
			spawns_ok = false
	if spawns_ok:
		var d: float = Vector2(bear).distance_to(Vector2(ghost))
		if d < cfg.min_spawn_dist:
			errors.append("distancia urso-fantasma %.1f < %.1f celulas" % [d, cfg.min_spawn_dist])

	# conectividade (flood-fill 4-vizinhos a partir do urso, ou da primeira livre)
	var free_total: int = 0
	var first_free: Vector2i = Vector2i(-1, -1)
	for r in rows:
		for c in cols:
			if not level.is_wall(c, r):
				free_total += 1
				if first_free.x < 0:
					first_free = Vector2i(c, r)
	var start: Vector2i = bear if (spawns_ok or (bear.x >= 0 and bear.x < cols and bear.y >= 0 and bear.y < rows and not level.is_wall(bear.x, bear.y))) else first_free
	if free_total > 0 and start.x >= 0:
		var seen: Dictionary = {start: true}
		var queue: Array[Vector2i] = [start]
		var qi: int = 0
		while qi < queue.size():
			var p: Vector2i = queue[qi]
			qi += 1
			for dv: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = p + dv
				if not seen.has(n) and not level.is_wall(n.x, n.y):
					seen[n] = true
					queue.append(n)
		if seen.size() != free_total:
			var lost: Array[String] = []
			for r in rows:
				for c in cols:
					if not level.is_wall(c, r) and not seen.has(Vector2i(c, r)):
						lost.append("(%d,%d)" % [c, r])
			errors.append("%d celula(s) livre(s) isolada(s)/nao conectada(s): %s" % [lost.size(), ", ".join(lost.slice(0, 6))])
	if free_total < cfg.min_free_cells:
		warnings.append("area livre %d < %d celulas" % [free_total, cfg.min_free_cells])

	# mecanicas
	for m: Node in level.get_mechanic_nodes():
		if m is Node2D:
			var mc: Vector2i = level.world_to_cell((m as Node2D).position)
			# janelas (bioma 6) ficam de proposito sobre parede
			var kind: Variant = m.get("kind")
			if kind == "window":
				if not level.is_wall(mc.x, mc.y):
					errors.append("janela '%s' fora de parede %s" % [m.name, str(mc)])
				continue
			if level.is_wall(mc.x, mc.y):
				errors.append("mecanica '%s' em parede %s" % [m.name, str(mc)])

	# densidade
	var dens: float = 1.0 - float(free_total) / float(cols * rows)
	if absf(dens - cfg.target_wall_density) > cfg.density_tolerance + 0.0005:
		var msg: String = "densidade %.1f%% fora de %.0f%% +-%.0fpp" % [dens * 100.0, cfg.target_wall_density * 100.0, cfg.density_tolerance * 100.0]
		if level.edicao_manual:
			warnings.append(msg + " (edicao manual)")
		else:
			errors.append(msg)
	return {"errors": errors, "warnings": warnings}


static func validate_all() -> Dictionary:
	var out: Dictionary = {}
	for i in LevelIndex.count():
		var scene: PackedScene = load(LevelIndex.scene_path(i)) as PackedScene
		var lvl: LevelRoot = scene.instantiate() as LevelRoot
		out[i] = validate(lvl)
		lvl.free()
	return out


func _initialize() -> void:
	var bad: int = 0
	var all: Dictionary = validate_all()
	for i: int in all:
		var res: Dictionary = all[i]
		var tag: String = LevelIndex.SLUGS[i]
		if (res["errors"] as Array).is_empty():
			print("OK    %s (%d aviso(s))" % [tag, (res["warnings"] as Array).size()])
		else:
			bad += 1
			print("FALHA %s" % tag)
			for e: String in res["errors"]:
				print("        erro: " + e)
		for w: String in res["warnings"]:
			print("        aviso: " + w)
	print("--- %d fase(s) com erro ---" % bad)
	quit(1 if bad > 0 else 0)
