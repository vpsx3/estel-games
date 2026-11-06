class_name VfxDirector
extends Node
## Liga os VFX (assets/vfx) aos eventos do jogo e ao estado da run, de forma DESACOPLADA do gameplay:
## escuta Events.* (pulo, mel, buffs, captura, bioma, aviso) e observa a GameRun por polling de estado
## (escudo, invisivel, veneno, fake_wall, rebound, slow, fantasmas congelados/presos/venenosos).
## Nao altera nenhum numero nem fluxo; so le. Criado/liberado pela cena de jogo (game.gd).

const FEET_DY: float = 21.0          ## igual a BearView.FEET_DY (pes do urso abaixo de bear.pos)
const AMBIENT_ICE: int = 7           ## brilhos de gelo espalhados (mecanica "ice"), seed fixa

var run: GameRun
var host: Node2D
var _loops: Dictionary = {}          # chave(String) -> VfxPlayer
var _prev_ghosts: Dictionary = {}    # GhostModel -> Vector2 (posicao no frame anterior)
var _seeded: bool = false
var _elim_pending: int = 0
var _boost_kind: String = ""         # "speed_temp" | "dash" (compartilham bear_boost_timer)
var _slow_kind: String = ""          # "ghost_slow" | "slow_time"
var _prev_shield: int = 0
var _warn_last: int = -1
var _mech_seen: Object = null
var _ambient: Array[VfxPlayer] = []


func bind(r: GameRun, h: Node2D) -> void:
	run = r
	host = h


func _ready() -> void:
	Events.bear_jumped.connect(_on_jump)
	Events.honey_collected.connect(_on_honey)
	Events.buff_activated.connect(_on_buff)
	Events.ghost_eliminated.connect(_on_ghost_eliminated)
	Events.game_over.connect(_on_game_over)
	Events.biome_changed.connect(_on_biome_changed)
	Events.biome_warning.connect(_on_biome_warning)


func _exit_tree() -> void:
	_disconnect(Events.bear_jumped, _on_jump)
	_disconnect(Events.honey_collected, _on_honey)
	_disconnect(Events.buff_activated, _on_buff)
	_disconnect(Events.ghost_eliminated, _on_ghost_eliminated)
	_disconnect(Events.game_over, _on_game_over)
	_disconnect(Events.biome_changed, _on_biome_changed)
	_disconnect(Events.biome_warning, _on_biome_warning)
	for fx: VfxPlayer in _loops.values():
		if is_instance_valid(fx):
			fx.queue_free()
	for fx2: VfxPlayer in _ambient:
		if is_instance_valid(fx2):
			fx2.queue_free()


func _disconnect(s: Signal, c: Callable) -> void:
	if s.is_connected(c):
		s.disconnect(c)


# ------------------------------------------------------------------ eventos
func _bear_feet() -> Vector2:
	return run.bear.pos + Vector2(0.0, FEET_DY)


func _play(id: String, pos: Vector2, opts: Dictionary = {}) -> void:
	if host == null:
		return
	opts["pos"] = pos
	VfxPlayer.spawn(host, id, opts)


func _on_jump() -> void:
	_play("jump", _bear_feet())


func _on_honey(_amount: int) -> void:
	_play("honey_pickup", run.bear.pos)


func _on_buff(id: String) -> void:
	if run == null:
		return
	var feet: Vector2 = _bear_feet()
	var west: bool = run.bear.facing == "west"
	match id:
		"speed_temp":
			_boost_kind = "speed_temp"
		"dash":
			_boost_kind = "dash"
			_play("dash", feet, {"flip": west})
		"freeze_all":
			_play("freeze_all", run.bear.pos)
		"teleport", "swap":
			_play(id, feet)
		"light_burst":
			_play("light_burst", feet)
		"light_bomb":
			_play("light_bomb", run.bear.pos)
		"lightning":   # o fantasma ja saiu da lista; usa a posicao do frame anterior do mais proximo
			_play("lightning", _nearest_prev_ghost_pos())
		"decoy":
			if run.decoy != null:
				_play("decoy", ((run.decoy as Dictionary)["pos"] as Vector2) + Vector2(0.0, FEET_DY))
		"ghost_slow":
			_slow_kind = "ghost_slow"
		"slow_time":
			_slow_kind = "slow_time"


func _nearest_prev_ghost_pos() -> Vector2:
	var best: Vector2 = run.bear.pos
	var bd: float = INF
	for g: GhostModel in _prev_ghosts:
		var d: float = (_prev_ghosts[g] as Vector2).distance_to(run.bear.pos)
		if d < bd:
			bd = d
			best = _prev_ghosts[g] as Vector2
	return best


func _on_ghost_eliminated(_tipo: String) -> void:
	_elim_pending += 1   # a posicao vem do diff de fantasmas em _process


func _on_game_over(_stats: Dictionary) -> void:
	if run != null:
		_play("caught", _bear_feet())


func _on_biome_changed(_idx: int) -> void:
	_warn_last = -1
	if run != null:
		_play("biome_transition", run.bear.pos)


func _on_biome_warning(seconds_left: float) -> void:
	var sec: int = ceili(seconds_left)
	if sec != _warn_last and sec % 3 == 1 and run != null:   # 10, 7, 4, 1
		_play("biome_warning", run.bear.pos + Vector2(0.0, -14.0))
	_warn_last = sec


# ------------------------------------------------------------------ estado
func _process(_dt: float) -> void:
	if run == null or host == null:
		return
	var bear: BearModel = run.bear
	var west: bool = bear.facing == "west"
	if run.bear_boost_timer <= 0.0:
		_boost_kind = ""
	if run.ghost_slow_timer <= 0.0:
		_slow_kind = ""
	_loop("speed", "speed_temp", _boost_kind == "speed_temp" and run.bear_boost_timer > 0.0, bear, FEET_DY, west)
	_loop("fake_wall", "fake_wall", run.phase_timer > 0.0, bear, FEET_DY)
	_loop("invisible", "invisible", run.invisible_timer > 0.0, bear, FEET_DY)   # + urso a=0.45 (BearView)
	_loop("rebound", "rebound", run.rebound_active, bear, FEET_DY)
	_loop("shield", "shield", run.shield_charges > 0, bear, FEET_DY)
	_loop("slow_time", "slow_time", _slow_kind == "slow_time" and run.ghost_slow_timer > 0.0, bear, FEET_DY)
	_loop("poisoned", "poisoned", bear.poisoned, bear, FEET_DY)
	if _prev_shield > run.shield_charges and run.shield_charges == 0:
		_play("shield_break", _bear_feet())
	_prev_shield = run.shield_charges
	_sync_ghosts()
	_sync_ambient()


func _sync_ghosts() -> void:
	var cur: Dictionary = {}
	for g: GhostModel in run.ghost_sys.ghosts:
		cur[g] = g.pos
		if _seeded and not _prev_ghosts.has(g):
			_play("ghost_spawn", g.pos)
		var k: String = str(g.get_instance_id())
		_loop("frozen#" + k, "ice_sparkle", g.frozen > 0.0, g, 0.0)
		_loop("trapped#" + k, "spirit_trap", g.trapped > 0.0, g, 0.0, false, true)
		_loop("slow#" + k, "ghost_slow", _slow_kind == "ghost_slow" and run.ghost_slow_timer > 0.0, g, 0.0)
		_loop("aura#" + k, "poison_aura", g.tipo == "venenoso", g, 0.0, false, false, Color(1, 1, 1, 0.55))
	for g: GhostModel in _prev_ghosts:
		if not cur.has(g) and _elim_pending > 0:
			_elim_pending -= 1
			_play("ghost_eliminated", _prev_ghosts[g] as Vector2)
	_prev_ghosts = cur
	_seeded = true
	# limpa overlays de fantasmas que sumiram
	for key: String in _loops.keys():
		if "#" in key:
			var gid: int = int(key.get_slice("#", 1))
			var alive: bool = false
			for g: GhostModel in cur:
				if g.get_instance_id() == gid:
					alive = true
					break
			if not alive:
				_stop(key)


## Mantem (ou encerra) um efeito em loop preso a um modelo.
func _loop(key: String, id: String, active: bool, target: Object, dy: float, flip: bool = false, force_loop: bool = false, tint: Color = Color.WHITE) -> void:
	var fx: VfxPlayer = _loops.get(key, null) as VfxPlayer
	if fx != null and not is_instance_valid(fx):
		_loops.erase(key)
		fx = null
	if active:
		if fx == null:
			fx = VfxPlayer.spawn(host, id, {"follow": target, "follow_dy": dy, "flip": flip, "loop": force_loop, "modulate": tint})
			if fx != null:
				_loops[key] = fx
		else:
			fx.set_flip(flip)
	elif fx != null:
		_stop(key)


func _stop(key: String) -> void:
	var fx: VfxPlayer = _loops.get(key, null) as VfxPlayer
	_loops.erase(key)
	if fx != null and is_instance_valid(fx):
		fx.stop_effect()


## Brilhos de gelo ambiente (mecanica ice): posicoes de seed fixa, refeitas quando a mecanica muda.
func _sync_ambient() -> void:
	if run.mech == _mech_seen:
		return
	_mech_seen = run.mech
	for fx: VfxPlayer in _ambient:
		if is_instance_valid(fx):
			fx.queue_free()
	_ambient.clear()
	if not (run.mech is MechIce) or run.level == null:
		return
	var cells: Array = GridCollision.free_cells(run.level)
	if cells.is_empty():
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()   # proprio: nao toca run.rng
	rng.seed = 424242
	for i in AMBIENT_ICE:
		var c: Vector2i = cells[rng.randi() % cells.size()] as Vector2i
		var fx: VfxPlayer = VfxPlayer.spawn(host, "ice_sparkle", {"pos": Units.cell_center(c.x, c.y), "z": 1, "modulate": Color(1, 1, 1, 0.8)})
		if fx != null:
			_ambient.append(fx)
