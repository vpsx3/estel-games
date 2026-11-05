class_name MechBase
extends RefCounted
## Base das mecanicas de bioma (estado `mech` do JS). A GameRun chama (todos opcionais):
##   update(run, dt), move_bear(run, dt, input)->bool, blocks_bear(x, y)->bool,
##   speed_mult(run)->float, apply_drift(run, dt), ghost_alpha()->float
## e a view chama draw_under(ci) / draw_over(ci).
## Regra de fallback (HANDOFF §3.4): cada subparte usa os MechMarker colocados em
## LevelRoot/Mecanicas do seu `kind`; se nao houver nenhum, gera proceduralmente como o JS
## (sorteios com run.rng). Parametros numericos: cfg (BIOME_MECH / BiomeConfig.mech).

const TEX_DIR: String = "res://assets/_placeholder/mechanics/"

static var _tex_cache: Dictionary = {}

var run: GameRun
var cfg: Dictionary = {}
var type: String = ""
var hand_nodes: Array = []   # filhos de Mecanicas (qualquer kind)


func _init(p_run: GameRun, p_cfg: Dictionary, p_hand: Array = []) -> void:
	run = p_run
	cfg = p_cfg
	type = str(p_cfg.get("type", ""))
	hand_nodes = p_hand


## Chamado pela fabrica depois do construtor (initMech*).
func setup() -> void:
	pass


# ---- interface com a GameRun (padroes neutros) ----
func update(_r: GameRun, _dt: float) -> void:
	pass


func move_bear(_r: GameRun, _dt: float, _input: Vector2) -> bool:
	return false


func blocks_bear(_x: float, _y: float) -> bool:
	return false


func speed_mult(_r: GameRun) -> float:
	return 1.0


func apply_drift(_r: GameRun, _dt: float) -> void:
	pass


func ghost_alpha() -> float:
	return 1.0


func draw_under(_ci: CanvasItem) -> void:
	pass


func draw_over(_ci: CanvasItem) -> void:
	pass


# ---- helpers de grade ----
func wall(c: int, r: int) -> bool:
	return bool(run.level.call("is_wall", c, r))


func bear_cell() -> Vector2i:
	return Units.world_to_cell(run.bear.pos)


func cfg_f(key: String) -> float:
	return float(cfg.get(key, 0.0))


## Celula seca mais proxima (aneis crescentes, Manhattan; empate = 1o na ordem dr, dc) fora de
## `blocked` (Dictionary Vector2i -> true). Porta mechNearestDry. null se nao achar.
func nearest_dry(sr: int, sc: int, blocked: Dictionary) -> Variant:
	for rad in range(1, maxi(Units.ROWS, Units.COLS)):
		var best: Variant = null
		var bd: int = 1 << 30
		for dr in range(-rad, rad + 1):
			for dc in range(-rad, rad + 1):
				if absi(dr) != rad and absi(dc) != rad:
					continue
				var r: int = sr + dr
				var c: int = sc + dc
				if r < 0 or r >= Units.ROWS or c < 0 or c >= Units.COLS or wall(c, r):
					continue
				if blocked.has(Vector2i(c, r)):
					continue
				var d: int = absi(dr) + absi(dc)
				if d < bd:
					bd = d
					best = Vector2i(c, r)
		if best != null:
			return best
	return null


## Empurrao justo: desliza o urso ate a celula seca mais proxima.
func push_to_dry(blocked: Dictionary) -> void:
	var bc: Vector2i = bear_cell()
	var dry: Variant = nearest_dry(bc.y, bc.x, blocked)
	if dry != null:
		var d: Vector2i = dry as Vector2i
		run.bear.glide_to(Units.cell_center(d.x, d.y))


## mechPickRandom: Fisher-Yates e primeiros n.
func pick_random(arr: Array, n: int) -> Array:
	var a: Array = arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j: int = int(run.rng.randf() * (i + 1))
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
	return a.slice(0, n)


# ---- marcadores colocados a mao ----
## MechMarker de um dos `kinds`. Vazio => comportamento procedural.
func markers(kinds: Array) -> Array:
	var out: Array = []
	for n in hand_nodes:
		if is_instance_valid(n) and str(n.get("kind")) in kinds:
			out.append(n)
	return out


func marker_cell(n: Node2D) -> Vector2i:
	if not n.is_inside_tree():
		return Units.world_to_cell(n.position)
	var origin: Vector2 = Vector2.ZERO
	if run.level is Node2D:
		origin = (run.level as Node2D).global_position
	return Units.world_to_cell(n.global_position - origin)


## No jogo o marcador some (a mecanica desenha o proprio visual animado).
func hide_markers(list: Array) -> void:
	if Engine.is_editor_hint():
		return
	for n in list:
		(n as CanvasItem).visible = false


static func tile_hash(r: int, c: int) -> int:
	return ((r * 73856093) ^ (c * 19349663)) & 0xFFFFFFFF


# ---- desenho ----
static func tex(slot: String) -> Texture2D:
	if _tex_cache.has(slot):
		return _tex_cache[slot] as Texture2D
	var path: String = TEX_DIR + slot + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_tex_cache[slot] = t
	return t


static func cell_rect(c: int, r: int) -> Rect2:
	return Rect2(c * Units.TILE, r * Units.TILE, Units.TILE, Units.TILE)


func draw_slot(ci: CanvasItem, slot: String, rect: Rect2, fallback: Color, modulate: Color = Color.WHITE) -> void:
	var t: Texture2D = tex(slot)
	if t != null:
		ci.draw_texture_rect(t, rect, false, modulate)
	else:
		ci.draw_rect(rect, fallback)
