class_name GridCollision
extends RefCounted
## Colisao por celula. Porta tileAt / canMove / freeCells / resolveLandingInsideWall.
## `level` = qualquer objeto com is_wall(c, r) -> bool (LevelRoot ou duplo de teste).
## Posicoes e tamanhos em px do Godot (size ja convertido por Units.px).


static func is_blocked_at(level: Object, x: float, y: float) -> bool:
	var c: int = floori(x / Units.TILE)
	var r: int = floori(y / Units.TILE)
	return bool(level.call("is_wall", c, r))


## canMove(x, y, sz): as 4 quinas da caixa (size * 0.45) precisam estar em celulas livres.
static func can_move(level: Object, x: float, y: float, size_px: float) -> bool:
	var r: float = size_px * GameplayLits.CAN_MOVE_HALF
	return not (is_blocked_at(level, x - r, y - r) or is_blocked_at(level, x + r, y - r)
		or is_blocked_at(level, x - r, y + r) or is_blocked_at(level, x + r, y + r))


## freeCells(): celulas livres do interior (linhas 1..ROWS-2, colunas 1..COLS-2), ordem r depois c.
static func free_cells(level: Object) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in range(1, Units.ROWS - 1):
		for c in range(1, Units.COLS - 1):
			if not bool(level.call("is_wall", c, r)):
				out.append(Vector2i(c, r))
	return out


## resolveLandingInsideWall(): celula livre mais proxima (aneis crescentes) onde o urso cabe.
## Retorna Vector2 (centro) ou null se ja esta livre / nao achou.
static func nearest_landing_target(level: Object, x: float, y: float, size_px: float) -> Variant:
	if can_move(level, x, y, size_px):
		return null
	var sc: int = floori(x / Units.TILE)
	var sr: int = floori(y / Units.TILE)
	var best: Variant = null
	var bd: float = INF
	for rad in range(1, maxi(Units.ROWS, Units.COLS) + 1):
		for dr in range(-rad, rad + 1):
			for dc in range(-rad, rad + 1):
				if absi(dr) != rad and absi(dc) != rad:
					continue
				var r: int = sr + dr
				var c: int = sc + dc
				if r < 0 or r >= Units.ROWS or c < 0 or c >= Units.COLS:
					continue
				if bool(level.call("is_wall", c, r)):
					continue
				var ctr: Vector2 = Units.cell_center(c, r)
				if not can_move(level, ctr.x, ctr.y, size_px):
					continue
				var d: float = ctr.distance_to(Vector2(x, y))
				if d < bd:
					bd = d
					best = ctr
		if best != null:
			break
	return best
