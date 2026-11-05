@tool
class_name LevelRoot
extends Node2D
## Raiz de cada fase (levels/biome_XX_<slug>.tscn). Logica = fonte da verdade (piso/parede);
## Visual = dual-grid gerado; DetalhePiso = variacoes de piso; Decor/Mecanicas/Spawns = posicionaveis.

const COLS: int = 18
const ROWS: int = 30
const CELL: int = 32

## Atlas coords dos 2 tiles de tilesets/editor_logic.tres
const TILE_FLOOR: Vector2i = Vector2i(0, 0)
const TILE_WALL: Vector2i = Vector2i(1, 0)
const LOGIC_SOURCE: int = 0
const VALIDATOR_PATH: String = "res://tools/editor/validate_levels.gd"

signal grid_changed

@export var config: BiomeConfig:
	set(v):
		config = v
		if is_node_ready():
			_apply_config()
## Marque se editou o mapa a mao: densidade fora da meta vira aviso em vez de erro.
@export var edicao_manual: bool = false
@export_range(0.0, 1.0, 0.01) var detail_density: float = 0.12
@export var detail_seed: int = 1337

@export_tool_button("Repintar visual", "Reload") var _btn_repaint: Callable = repaint_visual
@export_tool_button("Espalhar detalhes", "RandomNumberGenerator") var _btn_details: Callable = scatter_details
@export_tool_button("Validar fase", "StatusSuccess") var _btn_validate: Callable = validate_and_print

var _corner_map: Dictionary = {}
var _repaint_queued: bool = false


func _ready() -> void:
	_apply_config()
	var logica: TileMapLayer = get_node_or_null("Logica") as TileMapLayer
	if logica == null:
		return
	if Engine.is_editor_hint():
		if not logica.changed.is_connected(_on_logica_changed):
			logica.changed.connect(_on_logica_changed)
		set_process(true)
	else:
		logica.visible = false
		set_process(false)


func _process(_dt: float) -> void:
	# editor: spawns sempre no centro da celula
	for n: String in ["Spawns/SpawnUrso", "Spawns/SpawnFantasma"]:
		var m: Node2D = get_node_or_null(n) as Node2D
		if m != null:
			var snapped_pos: Vector2 = cell_to_world(world_to_cell(m.position))
			if m.position != snapped_pos:
				m.position = snapped_pos


func _apply_config() -> void:
	_corner_map = {}
	if config == null:
		return
	_corner_map = DualGridPainter.load_corner_map(config.corner_map_path)
	var visual: TileMapLayer = get_node_or_null("Visual") as TileMapLayer
	if visual != null and config.tileset != null:
		visual.tile_set = config.tileset


# ---------- consulta ----------

func _logica() -> TileMapLayer:
	return get_node_or_null("Logica") as TileMapLayer


func is_wall(c: int, r: int) -> bool:
	if c < 0 or r < 0 or c >= COLS or r >= ROWS:
		return true
	var l: TileMapLayer = _logica()
	if l == null:
		return true
	var cell: Vector2i = Vector2i(c, r)
	return l.get_cell_source_id(cell) == LOGIC_SOURCE and l.get_cell_atlas_coords(cell) == TILE_WALL


func set_wall(c: int, r: int, wall: bool) -> void:
	if c < 0 or r < 0 or c >= COLS or r >= ROWS:
		return
	var l: TileMapLayer = _logica()
	if l == null:
		return
	l.set_cell(Vector2i(c, r), LOGIC_SOURCE, TILE_WALL if wall else TILE_FLOOR)
	if not Engine.is_editor_hint():
		var visual: TileMapLayer = get_node_or_null("Visual") as TileMapLayer
		if visual != null:
			DualGridPainter.paint_around(visual, is_wall, _corner_map, c, r, COLS, ROWS)
	grid_changed.emit()


func get_grid() -> Array:
	var g: Array = []
	for r in ROWS:
		var row: Array = []
		for c in COLS:
			row.append(1 if is_wall(c, r) else 0)
		g.append(row)
	return g


## Grava uma grade 0/1 completa em Logica (importacao / testes).
func load_grid(g: Array) -> void:
	var l: TileMapLayer = _logica()
	l.clear()
	for r in ROWS:
		for c in COLS:
			l.set_cell(Vector2i(c, r), LOGIC_SOURCE, TILE_WALL if int((g[r] as Array)[c]) == 1 else TILE_FLOOR)


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL + CELL / 2.0, cell.y * CELL + CELL / 2.0)


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


func bear_spawn_cell() -> Vector2i:
	var m: Node2D = get_node_or_null("Spawns/SpawnUrso") as Node2D
	return world_to_cell(m.position) if m != null else Vector2i(-1, -1)


func ghost_spawn_cell() -> Vector2i:
	var m: Node2D = get_node_or_null("Spawns/SpawnFantasma") as Node2D
	return world_to_cell(m.position) if m != null else Vector2i(-1, -1)


func get_mechanic_nodes() -> Array[Node]:
	var out: Array[Node] = []
	var m: Node = get_node_or_null("Mecanicas")
	if m != null:
		out.assign(m.get_children())
	return out


# ---------- visual ----------

func _on_logica_changed() -> void:
	if _repaint_queued:
		return
	_repaint_queued = true
	repaint_visual.call_deferred()
	grid_changed.emit.call_deferred()


func repaint_visual() -> void:
	_repaint_queued = false
	_apply_config()
	var visual: TileMapLayer = get_node_or_null("Visual") as TileMapLayer
	if visual == null or _corner_map.is_empty():
		return
	visual.position = Vector2(-CELL / 2.0, -CELL / 2.0)
	DualGridPainter.paint_all(visual, is_wall, _corner_map, COLS, ROWS)


func scatter_details() -> void:
	var det: TileMapLayer = get_node_or_null("DetalhePiso") as TileMapLayer
	if det == null:
		return
	det.clear()
	if config == null or config.detail_tiles == null or config.detail_tiles.get_source_count() == 0:
		push_warning("%s: config.detail_tiles vazio; nada a espalhar." % name)
		return
	det.tile_set = config.detail_tiles
	var src_id: int = config.detail_tiles.get_source_id(0)
	var src: TileSetAtlasSource = config.detail_tiles.get_source(src_id) as TileSetAtlasSource
	if src == null or src.get_tiles_count() == 0:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = detail_seed
	for r in ROWS:
		for c in COLS:
			var roll: float = rng.randf()
			var pick: int = rng.randi() % src.get_tiles_count()
			if not is_wall(c, r) and roll < detail_density:
				det.set_cell(Vector2i(c, r), src_id, src.get_tile_id(pick))


func validate_and_print() -> Dictionary:
	var res: Dictionary = (load(VALIDATOR_PATH) as GDScript).call("validate", self) as Dictionary
	for e: String in res["errors"]:
		printerr("[%s] ERRO: %s" % [name, e])
	for w: String in res["warnings"]:
		push_warning("[%s] aviso: %s" % [name, w])
	if (res["errors"] as Array).is_empty():
		print("[%s] fase valida (%d aviso(s))" % [name, (res["warnings"] as Array).size()])
	return res
