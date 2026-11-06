class_name MechTide
extends MechBase
## Mare ciclica (bioma 1). Porta mechInitTide / mechUpdateTide / mechDrawTide.
## Global: so configuracao (speed, maxRows); sem marcadores.

var flooded: Dictionary = {}     # Vector2i -> true
var flooded_rows: Array[int] = []


func update(r: GameRun, _dt: float) -> void:
	var lvl: float = sin(r.elapsed * cfg_f("speed")) * 0.5 + 0.5
	var n_rows: int = floori(lvl * cfg_f("maxRows"))
	var rows: Array[int] = []
	var rr: int = Units.ROWS - 2
	while rr >= 1 and rows.size() < n_rows:   # linhas de chao mais ao fundo (maior r)
		for c in range(1, Units.COLS - 1):
			if not wall(c, rr):
				rows.append(rr)
				break
		rr -= 1
	var fl: Dictionary = {}
	for row in rows:
		for c in Units.COLS:
			if not wall(c, row):
				fl[Vector2i(c, row)] = true
	flooded = fl
	flooded_rows = rows
	# empurrao justo: mare alcancou o urso -> celula seca mais proxima (nao afoga)
	if flooded.has(bear_cell()) and r.bear.landing_target == null:
		push_to_dry(flooded)


func blocks_bear(x: float, y: float) -> bool:
	return flooded.has(Units.world_to_cell(Vector2(x, y)))


var _overlay: WaterOverlay


func attach_nodes(host: Node2D) -> void:
	_overlay = WaterOverlay.new()   # agua com shader (scroll + brilho) atras do desenho da WorldView
	host.add_child(_overlay)


func draw_under(ci: CanvasItem) -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.set_state(flooded.keys(), run.elapsed)
	else:   # sem a camada (testes/fallback): retangulos
		for cell: Vector2i in flooded:
			ci.draw_rect(cell_rect(cell.x, cell.y), Color(0.157, 0.43, 0.78, 0.8))
	for cell: Vector2i in flooded:
		if flooded.has(Vector2i(cell.x, cell.y - 1)):
			continue
		var sway: float = sin(run.elapsed * 3.0 + cell.x * 0.6) * Units.px(2.0)
		var ctr: Vector2 = Vector2(cell.x * Units.TILE + Units.TILE / 2.0, cell.y * Units.TILE + sway)
		draw_tex(ci, frame_at("foam", "default", run.elapsed + cell.x * 0.13), ctr, Color(1, 1, 1, 0.55), Color.WHITE, Vector2(Units.TILE, Units.TILE * 0.5))
