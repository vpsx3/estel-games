@tool
class_name DualGridPainter
extends RefCounted
## Pinta a camada Visual (19x31, deslocada (-16,-16)) a partir da grade logica.
## Celula visual (i,j) olha NW=(i-1,j-1) NE=(i,j-1) SW=(i-1,j) SE=(i,j) da logica.
## Bitmask: NW=8, NE=4, SW=2, SE=1; canto 'upper' = parede. Fora do grid = parede.
## corner_map: {bitmask:int -> Vector2i(atlas)} (16 entradas), via load_corner_map().

const NW: int = 8
const NE: int = 4
const SW: int = 2
const SE: int = 1


static func load_corner_map(path: String) -> Dictionary:
	var out: Dictionary = {}
	if path.is_empty() or not FileAccess.file_exists(path):
		return out
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return out
	var m: Dictionary = (data as Dictionary).get("map", {}) as Dictionary
	for k: Variant in m:
		var v: Array = m[k] as Array
		out[int(k)] = Vector2i(int(v[0]), int(v[1]))
	return out


static func bitmask(is_wall: Callable, vc: int, vr: int) -> int:
	var b: int = 0
	if is_wall.call(vc - 1, vr - 1): b |= NW
	if is_wall.call(vc, vr - 1): b |= NE
	if is_wall.call(vc - 1, vr): b |= SW
	if is_wall.call(vc, vr): b |= SE
	return b


## Repinta tudo. Retorna o numero de celulas pintadas.
static func paint_all(visual: TileMapLayer, is_wall: Callable, corner_map: Dictionary, cols: int, rows: int, source_id: int = 0) -> int:
	visual.clear()
	var n: int = 0
	for vr in rows + 1:
		for vc in cols + 1:
			n += _paint_cell(visual, is_wall, corner_map, vc, vr, source_id)
	return n


## Repinta so as 4 celulas visuais em volta da celula logica (c,r).
static func paint_around(visual: TileMapLayer, is_wall: Callable, corner_map: Dictionary, c: int, r: int, cols: int, rows: int, source_id: int = 0) -> void:
	for vr in [r, r + 1]:
		for vc in [c, c + 1]:
			if vc >= 0 and vc <= cols and vr >= 0 and vr <= rows:
				_paint_cell(visual, is_wall, corner_map, vc, vr, source_id)


static func _paint_cell(visual: TileMapLayer, is_wall: Callable, corner_map: Dictionary, vc: int, vr: int, source_id: int) -> int:
	var b: int = bitmask(is_wall, vc, vr)
	if not corner_map.has(b):
		return 0
	visual.set_cell(Vector2i(vc, vr), source_id, corner_map[b] as Vector2i)
	return 1
