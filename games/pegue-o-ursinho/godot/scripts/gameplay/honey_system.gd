class_name HoneySystem
extends RefCounted
## Economia do mel dentro da run. Porta honeyDrops/honeySpawnTimer/honeyPassiveAcc,
## spawnHoney, updateHoney e o ganho passivo do gameLoop.
##   passivo: HONEY_PASSIVE_RATE/s (acumulador fracionario)
##   pote: a cada HONEY_SPAWN_INTERVAL s, ate HONEY_MAX_ON_MAP, vive HONEY_LIFE s,
##         coleta se dist < bear.size + px(HONEY_R), vale HONEY_PICKUP_VALUE.
## O mel acumulado (run_honey) vive em GameRun.run_honey.

var run: GameRun
var drops: Array[Dictionary] = []   # {pos: Vector2, life: float, born: float}
var spawn_timer: float = 0.0
var passive_acc: float = 0.0


func _init(p_run: GameRun) -> void:
	run = p_run


func reset() -> void:
	drops.clear()
	spawn_timer = GameplayLits.c("HONEY_SPAWN_INTERVAL")
	passive_acc = 0.0


func spawn_honey() -> void:
	var bear_pos: Vector2 = run.bear.pos
	var cells: Array[Vector2i] = []
	for cell in GridCollision.free_cells(run.level):
		var ctr: Vector2 = Units.cell_center(cell.x, cell.y)
		if ctr.distance_to(bear_pos) < Units.TILE * GameplayLits.HONEY_BEAR_MIN_CELLS:
			continue
		var near: bool = false
		for h in drops:
			if (h["pos"] as Vector2).distance_to(ctr) < Units.TILE * GameplayLits.HONEY_SPACING_CELLS:
				near = true
				break
		if not near:
			cells.append(cell)
	if cells.is_empty():
		cells = GridCollision.free_cells(run.level)
	if cells.is_empty():
		return
	var cell: Vector2i = cells[int(run.rng.randf() * cells.size())]
	drops.append({"pos": Units.cell_center(cell.x, cell.y), "life": GameplayLits.c("HONEY_LIFE"), "born": run.rng.randf() * 6.0})


func update(dt: float) -> void:
	spawn_timer -= dt
	if spawn_timer <= 0.0:
		if drops.size() < int(GameplayLits.c("HONEY_MAX_ON_MAP")):
			spawn_honey()
		spawn_timer = GameplayLits.c("HONEY_SPAWN_INTERVAL")
	var pick_r: float = run.bear.size + Units.px(GameplayLits.c("HONEY_R"))
	for i in range(drops.size() - 1, -1, -1):
		var h: Dictionary = drops[i]
		h["life"] = float(h["life"]) - dt
		if float(h["life"]) <= 0.0:
			drops.remove_at(i)
			continue
		if run.bear.pos.distance_to(h["pos"] as Vector2) < pick_r:
			var v: int = int(GameplayLits.c("HONEY_PICKUP_VALUE"))
			run.add_honey(v)
			Events.honey_collected.emit(v)
			drops.remove_at(i)


## Ganho passivo do gameLoop.
func update_passive(dt: float) -> void:
	passive_acc += GameplayLits.c("HONEY_PASSIVE_RATE") * dt
	if passive_acc >= 1.0:
		var inc: int = floori(passive_acc)
		run.add_honey(inc)
		passive_acc -= inc
