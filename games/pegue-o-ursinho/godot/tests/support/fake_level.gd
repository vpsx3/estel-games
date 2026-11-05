extends Node2D
## Duplo de teste do contrato LevelRoot (a partir de GameState/maps.json). Usado pelos testes
## e como fallback do game.tscn quando LevelIndex ainda nao existe.
## Contrato: COLS/ROWS/CELL, config, grid_changed, is_wall, set_wall, get_grid,
## bear_spawn_cell, ghost_spawn_cell, cell_to_world, world_to_cell, get_mechanic_nodes.

signal grid_changed

const COLS: int = 18
const ROWS: int = 30
const CELL: int = 32


class FakeConfig extends RefCounted:
	var index: int = 0
	var slug: String = ""
	var name_pt: String = ""
	var name_en: String = ""
	var ghost_speed: float = 1.0
	var ghost_spawn_rate: float = 20.0
	var mech_type: String = ""
	var mech: Dictionary = {}
	var wall_tint: Color = Color.WHITE
	var bg_color: Color = Color.BLACK


var config: FakeConfig = FakeConfig.new()
var _grid: Array = []   # [r][c] 0/1
var _bear_cell: Vector2i = Vector2i(8, 14)
var _ghost_cell: Vector2i = Vector2i(16, 28)


func setup(idx: int) -> Node2D:
	var src: Array = GameState.maps[idx]
	_grid = []
	for row: Array in src:
		_grid.append((row as Array).duplicate())
	var b: Dictionary = GameState.biomes[idx]
	config.index = idx
	config.name_pt = str(b["name"])
	config.name_en = str((GameState.strings_en["biome_names"] as Dictionary).get(str(int(b["id"])), b["name"]))
	config.ghost_speed = float(b["ghostSpeed"])
	config.ghost_spawn_rate = float(b["ghostSpawnRate"])
	config.wall_tint = Color(str(b["wallTint"]))
	config.bg_color = Color(str(b["bgColor"]))
	var m: Dictionary = GameState.mech_config(idx)
	config.mech_type = str(m.get("type", ""))
	config.mech = m
	_bear_cell = Vector2i(int((b["bearSpawn"] as Dictionary)["c"]), int((b["bearSpawn"] as Dictionary)["r"]))
	_ghost_cell = Vector2i(int((b["ghostSpawn"] as Dictionary)["c"]), int((b["ghostSpawn"] as Dictionary)["r"]))
	queue_redraw()
	return self


func is_wall(c: int, r: int) -> bool:
	if r < 0 or r >= ROWS or c < 0 or c >= COLS:
		return true
	return int((_grid[r] as Array)[c]) == 1


func set_wall(c: int, r: int, wall: bool) -> void:
	if r < 0 or r >= ROWS or c < 0 or c >= COLS:
		return
	(_grid[r] as Array)[c] = 1 if wall else 0
	grid_changed.emit()
	queue_redraw()


func get_grid() -> Array:
	return _grid


func bear_spawn_cell() -> Vector2i:
	return _bear_cell


func ghost_spawn_cell() -> Vector2i:
	return _ghost_cell


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * CELL, (cell.y + 0.5) * CELL)


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))


func get_mechanic_nodes() -> Array:
	return []


func _draw() -> void:
	draw_rect(Rect2(0, 0, COLS * CELL, ROWS * CELL), config.bg_color)
	for r in ROWS:
		for c in COLS:
			if is_wall(c, r):
				draw_rect(Rect2(c * CELL, r * CELL, CELL, CELL), config.wall_tint)
