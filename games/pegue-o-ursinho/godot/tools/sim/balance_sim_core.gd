extends RefCounted
## Simulador headless de balanceamento com bot. Monta a run como a cena de jogo (niveis reais
## levels/biome_*.tscn, MechFactory, BuffSystem com auto_choice) e joga N runs com um bot simples.
##
## Implementacao (carregada em runtime por balance_sim.gd porque autoloads nao compilam no script principal).
## Uso:
##   "$GODOT_PATH" --headless --path games/pegue-o-ursinho/godot --script res://tools/sim/balance_sim.gd \
##       -- --runs=200 --attr=0 --seed0=1 [--out=C:/caminho/saida.json] [--max-s=900] [--quiet]
##
## --attr=N : todos os atributos no nivel N (double_jump/reroll so se N>=10).
## Bot: BFS (prof. 9) a cada 0,15 s; escolhe a celula com maior "margem" (tempo do fantasma mais
## rapido ate a celula menos tempo do urso); com margem folgada (> 1,5 s) vai ao mel/orbe mais perto.
## Pula quando o fantasma mais proximo esta a < 1,4 celula. So usa API publica da GameRun.

const DT: float = 1.0 / 30.0
const REPLAN: float = 0.15
const BFS_DEPTH: int = 9
const SAFE_MARGIN: float = 1.5
const JUMP_CELLS: float = 1.4

var _runs: int = 200
var _attr: int = 0
var _seed0: int = 1
var _max_s: float = 900.0
var _out: String = ""
var _quiet: bool = false
var _trace: bool = false
var _path_min: bool = false  # variante: margem = minimo ao longo do caminho (--pathmin liga)
var _no_idle: bool = true    # com fantasma a < 4 celulas nao fica parado (--allow-idle desliga)

var _scenes: Array[PackedScene] = []
var _prev_level: Node = null

# estado do bot (por run)
var _replan_t: float = 0.0
var _move: Vector2 = Vector2.ZERO
var _wall_level: Object = null
var _walls: PackedByteArray = PackedByteArray()


func run_sim() -> void:
	_parse_args()
	_load_scenes()
	var results: Array[Dictionary] = []
	var t0: int = Time.get_ticks_msec()
	for i in _runs:
		results.append(_play_run(_seed0 + i))
		if not _quiet and (i + 1) % 20 == 0:
			printerr("  ... %d/%d runs (%.0fs)" % [i + 1, _runs, (Time.get_ticks_msec() - t0) / 1000.0])
	_report(results)


func _parse_args() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			_runs = int(a.get_slice("=", 1))
		elif a.begins_with("--attr="):
			_attr = int(a.get_slice("=", 1))
		elif a.begins_with("--seed0="):
			_seed0 = int(a.get_slice("=", 1))
		elif a.begins_with("--max-s="):
			_max_s = float(a.get_slice("=", 1))
		elif a.begins_with("--out="):
			_out = a.substr(6)
		elif a == "--pathmin":
			_path_min = true
		elif a == "--allow-idle":
			_no_idle = false
		elif a == "--trace":
			_trace = true
		elif a == "--quiet":
			_quiet = true
	if _out == "":
		_out = "user://balance_sim_attr%d.json" % _attr


func _load_scenes() -> void:
	var n: int = LevelIndex.count()
	for i in n:
		_scenes.append(load(LevelIndex.scene_path(i)) as PackedScene)


# ---------------------------------------------------------------- montagem da run
func _make_level(i: int) -> Object:
	var node: Node = (_scenes[i % _scenes.size()] as PackedScene).instantiate()
	if _prev_level != null and is_instance_valid(_prev_level):
		_prev_level.free()
	_prev_level = node
	return node


func _attr_levels() -> Dictionary:
	var out: Dictionary = {}
	for id: String in Shop.order():
		var mx: int = int(Shop.def(id).get("maxLevel", 10))
		if id == "double_jump" or id == "reroll":
			out[id] = mini(1, mx) if _attr >= 10 else 0
		else:
			out[id] = mini(_attr, mx)
	return out


func _play_run(seed_value: int) -> Dictionary:
	GameState.reset_run()
	var run: GameRun = GameRun.new(seed_value)
	run.sync_game_state = true
	run.attr_levels = _attr_levels()
	MechFactory.install(run)
	var buffs: BuffSystem = BuffSystem.new(run)
	buffs.attach()
	buffs.auto_choice = false
	run.level_loader = _make_level
	var level: Object = _make_level(0)
	buffs.open_selection()
	buffs.auto_choice = true
	buffs.auto_pick()
	buffs.start_run(level)

	_replan_t = 0.0
	_move = Vector2.ZERO
	_wall_level = null

	var biome_entered: Array[int] = [run.cycle.current_biome]   # visitas (inclui ciclos)
	var biome_ghosts_end: Array[Array] = []                      # [biome_idx, ghosts_vivos_no_fim]
	var last_biome: int = run.cycle.current_biome
	var last_ghosts: int = run.ghosts.size()
	var max_ghosts: int = last_ghosts
	var frames: int = int(_max_s / DT)
	for f in frames:
		if run.state != "playing":
			break
		_bot_tick(run)
		run.step(DT, _move)
		if _trace and f % 15 == 0:
			var ln: String = "t=%.1f b%d bear=%s mv=%s |" % [run.elapsed, run.cycle.current_biome, run.bear.pos, _move]
			for g: GhostModel in run.ghosts:
				ln += " %s/%.0f" % [g.tipo, g.pos.distance_to(run.bear.pos)]
			print(ln)
		var cb: int = run.cycle.current_biome
		if cb != last_biome and run.state == "playing":
			biome_ghosts_end.append([last_biome, last_ghosts])
			biome_entered.append(cb)
			last_biome = cb
		last_ghosts = run.ghosts.size()
		max_ghosts = maxi(max_ghosts, last_ghosts)

	var died: bool = run.state == "lose"
	var res: Dictionary = {
		"seed": seed_value,
		"seconds": run.elapsed,
		"died": died,
		"biome": run.cycle.current_biome,
		"cycle": run.cycle.cycle_count,
		"ghosts": run.ghosts.size(),
		"max_ghosts": max_ghosts,
		"honey": run.run_honey,
		"entered": biome_entered,
		"ghosts_end": biome_ghosts_end,
	}
	return res


# ---------------------------------------------------------------- bot
func _call(obj: Object, m: String, args: Array = [], default: Variant = null) -> Variant:
	if obj != null and obj.has_method(m):
		return obj.callv(m, args)
	return default


func _refresh_walls(run: GameRun) -> void:
	if _wall_level == run.level:
		return
	_wall_level = run.level
	_walls.resize(Units.COLS * Units.ROWS)
	for r in Units.ROWS:
		for c in Units.COLS:
			_walls[r * Units.COLS + c] = 1 if bool(run.level.call("is_wall", c, r)) else 0


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(floori(p.x / Units.TILE), 0, Units.COLS - 1), clampi(floori(p.y / Units.TILE), 0, Units.ROWS - 1))


func _walkable(run: GameRun, c: int, r: int) -> bool:
	if c < 0 or r < 0 or c >= Units.COLS or r >= Units.ROWS:
		return false
	if _walls[r * Units.COLS + c] == 1:
		return false
	var ctr: Vector2 = Units.cell_center(c, r)
	if bool(_call(run, "mech_blocks_bear", [ctr.x, ctr.y], false)):
		return false
	return true


func _bear_speed(run: GameRun) -> float:
	var mult: float = float(_call(run, "bear_speed_mult", [], 1.0)) * float(_call(run, "mech_speed_mult", [], 1.0))
	if bool(run.bear.poisoned):
		mult *= float(GameplayLits.c("POISON_DEBUFF"))
	return maxf(1.0, Units.speed_px_frame_to_px_s(run.bear.speed * mult))


func _bot_tick(run: GameRun) -> void:
	if run.cycle.phase == "choosing":
		_move = Vector2.ZERO
		return
	_replan_t -= DT
	if _replan_t <= 0.0:
		_replan_t = REPLAN
		_replan(run)
	else:
		_steer(run)
	# pulo: fantasma mais proximo a < 1,4 celula
	var near_d: float = INF
	for g: GhostModel in run.ghosts:
		near_d = minf(near_d, g.pos.distance_to(run.bear.pos))
	if near_d < Units.TILE * JUMP_CELLS:
		run.try_jump()


## Ritmo de movimento: _path_first guarda o centro da proxima celula; _steer converte em input.
var _next_center: Vector2 = Vector2.ZERO
var _has_next: bool = false


func _steer(run: GameRun) -> void:
	if not _has_next:
		_move = Vector2.ZERO
		return
	var bp: Vector2 = run.bear.pos
	var d: Vector2 = _next_center - bp
	if d.length() < 2.0:
		_move = Vector2.ZERO
		return
	# alinha o eixo perpendicular ao movimento para nao raspar quina de parede
	var cur: Vector2 = Units.cell_center(_cell_of(bp).x, _cell_of(bp).y)
	var nxt_c: Vector2i = _cell_of(_next_center)
	var cur_c: Vector2i = _cell_of(bp)
	var step: Vector2i = nxt_c - cur_c
	var m: Vector2 = d.normalized()
	if step != Vector2i.ZERO and (absi(step.x) + absi(step.y)) == 1:
		var perp: float = (bp.y - cur.y) if step.x != 0 else (bp.x - cur.x)
		var corr: float = clampf(-perp / 6.0, -1.0, 1.0)
		var along: float = 1.0 if absf(perp) < 9.0 else 0.35
		if step.x != 0:
			m = Vector2(signf(step.x) * along, corr)
		else:
			m = Vector2(corr, signf(step.y) * along)
	_move = m


func _replan(run: GameRun) -> void:
	_refresh_walls(run)
	var start: Vector2i = _cell_of(run.bear.pos)
	var vb: float = _bear_speed(run)
	var gm: float = float(_call(run, "ghost_global_mult", [], 1.0))

	# fantasmas relevantes: [pos, vel px/s]
	var gp: Array[Vector2] = []
	var gv: Array[float] = []
	for g: GhostModel in run.ghosts:
		if g.frozen > 0.0 or g.trapped > 0.0:
			continue
		var per: float = g.boost_mult if g.boost_timer > 0.0 else 1.0
		gp.append(g.pos)
		gv.append(maxf(1.0, Units.speed_px_frame_to_px_s(g.speed * gm * per)))

	# alvos: potes de mel e orbes coletaveis
	var targets: Array[Vector2] = []
	var hs: Variant = run.get("honey")
	if hs != null:
		var drops: Variant = (hs as Object).get("drops")
		if drops is Array:
			for h: Variant in drops:
				if h is Dictionary and (h as Dictionary).has("pos"):
					targets.append((h as Dictionary)["pos"] as Vector2)
	var bf: Variant = run.get("buffs")
	if bf != null:
		var cols: Variant = (bf as Object).get("collectibles")
		if cols is Array:
			for c: Variant in cols:
				if c is Dictionary and (c as Dictionary).has("pos"):
					targets.append((c as Dictionary)["pos"] as Vector2)

	# BFS 4-conexa ate BFS_DEPTH; guarda 1o passo e profundidade
	var w: int = Units.COLS
	var depth: Dictionary = {}
	var first: Dictionary = {}
	var parent: Dictionary = {}
	var qi: int = 0
	var queue: Array[Vector2i] = [start]
	depth[start] = 0
	first[start] = start
	while qi < queue.size():
		var cur: Vector2i = queue[qi]
		qi += 1
		var dcur: int = depth[cur]
		if dcur >= BFS_DEPTH:
			continue
		for dv: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + dv
			if depth.has(nb) or not _walkable(run, nb.x, nb.y):
				continue
			depth[nb] = dcur + 1
			first[nb] = nb if cur == start else first[cur]
			parent[nb] = cur
			queue.append(nb)
	var _unused: int = w

	var idle_banned: bool = false
	if _no_idle:
		for k in gp.size():
			if gp[k].distance_to(run.bear.pos) < Units.TILE * 4.0:
				idle_banned = true
	var best_cell: Vector2i = start
	var best_margin: float = -INF
	var margins: Dictionary = {}
	for cell: Vector2i in queue:
		var ctr: Vector2 = Units.cell_center(cell.x, cell.y)
		var t_bear: float = float(depth[cell]) * Units.TILE / vb
		var mg: float = INF
		for k in gp.size():
			mg = minf(mg, gp[k].distance_to(ctr) / gv[k] - t_bear)
		if gp.is_empty():
			mg = 99.0
		if _path_min and cell != start:
			mg = minf(mg, float(margins[parent[cell]]))   # margem do caminho = pior celula ao longo dele
		margins[cell] = mg
		if cell == start and idle_banned and queue.size() > 1:
			continue
		if mg > best_margin:
			best_margin = mg
			best_cell = cell

	var chosen: Vector2i = best_cell
	if best_margin > SAFE_MARGIN and not targets.is_empty():
		var bd: float = INF
		for cell: Vector2i in queue:
			if float(margins[cell]) <= SAFE_MARGIN:
				continue
			var ctr2: Vector2 = Units.cell_center(cell.x, cell.y)
			var dmin: float = INF
			for t: Vector2 in targets:
				dmin = minf(dmin, ctr2.distance_to(t))
			if dmin < bd:
				bd = dmin
				chosen = cell

	if chosen == start:
		_has_next = false
		_move = Vector2.ZERO
		# fica parado, mas se o alvo (mel) esta nesta celula nada a fazer
		return
	var nxt: Vector2i = first[chosen]
	_next_center = Units.cell_center(nxt.x, nxt.y)
	_has_next = true
	_steer(run)


# ---------------------------------------------------------------- relatorio
func _pct(sorted: Array, p: float) -> float:
	if sorted.is_empty():
		return 0.0
	var idx: float = p * float(sorted.size() - 1)
	var lo: int = floori(idx)
	var hi: int = ceili(idx)
	return float(sorted[lo]) + (float(sorted[hi]) - float(sorted[lo])) * (idx - lo)


func _report(results: Array[Dictionary]) -> void:
	var secs: Array = []
	var honey_sum: float = 0.0
	var timeouts: int = 0
	var n_b: int = LevelIndex.count()
	var entered: Array[int] = []
	var died_in: Array[int] = []
	var gh_sum: Array[float] = []
	var gh_cnt: Array[int] = []
	var ghosts_death_sum: float = 0.0
	var deaths: int = 0
	for i in n_b:
		entered.append(0)
		died_in.append(0)
		gh_sum.append(0.0)
		gh_cnt.append(0)
	for r: Dictionary in results:
		secs.append(float(r["seconds"]))
		honey_sum += float(r["honey"])
		if not bool(r["died"]):
			timeouts += 1
		else:
			deaths += 1
			died_in[int(r["biome"])] += 1
			ghosts_death_sum += float(r["ghosts"])
		for b: int in (r["entered"] as Array):
			entered[b] += 1
		for pr: Array in (r["ghosts_end"] as Array):
			gh_sum[int(pr[0])] += float(pr[1])
			gh_cnt[int(pr[0])] += 1
	secs.sort()
	var n: float = maxf(1.0, float(results.size()))
	var mean: float = 0.0
	for s: float in secs:
		mean += s
	mean /= n
	var lines: PackedStringArray = []
	lines.append("=== balance_sim: runs=%d attr=%d seed0=%d (dt=1/30, limite %ds) ===" % [results.size(), _attr, _seed0, int(_max_s)])
	lines.append("sobrevivencia (s): media %.1f | mediana %.1f | p10 %.1f | p90 %.1f | min %.1f | max %.1f" % [
		mean, _pct(secs, 0.5), _pct(secs, 0.1), _pct(secs, 0.9), _pct(secs, 0.0), _pct(secs, 1.0)])
	lines.append("mel medio/run: %.1f | mortes: %d | runs que bateram o limite: %d | fantasmas vivos na morte (media): %.1f" % [
		honey_sum / n, deaths, timeouts, ghosts_death_sum / maxf(1.0, float(deaths))])
	lines.append("bioma | entraram | morreram | %morte | fant. vivos no fim do bioma (media)")
	for i in n_b:
		var pct: float = 100.0 * float(died_in[i]) / float(entered[i]) if entered[i] > 0 else 0.0
		var gend: String = "%.1f" % (gh_sum[i] / float(gh_cnt[i])) if gh_cnt[i] > 0 else "-"
		lines.append("%2d %-26s | %5d | %5d | %5.1f%% | %s" % [i + 1, _slug(i), entered[i], died_in[i], pct, gend])
	for l in lines:
		print(l)
	var payload: Dictionary = {
		"runs": results.size(), "attr": _attr, "seed0": _seed0, "max_s": _max_s,
		"mean_s": mean, "median_s": _pct(secs, 0.5), "p10_s": _pct(secs, 0.1), "p90_s": _pct(secs, 0.9),
		"honey_mean": honey_sum / n, "deaths": deaths, "timeouts": timeouts,
		"biome_entered": entered, "biome_died": died_in,
		"results": results,
	}
	var f: FileAccess = FileAccess.open(_out, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload))
		f.close()
		print("json: %s" % ProjectSettings.globalize_path(_out))
	else:
		printerr("nao foi possivel gravar %s" % _out)


func _slug(i: int) -> String:
	return LevelIndex.SLUGS[i].substr(3)
