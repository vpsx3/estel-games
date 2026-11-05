class_name Units
extends RefCounted
## Conversao de unidades legadas (HTML, TILE=36) para o Godot (TILE=32). Ver HANDOFF §3.3.
##
## Regras:
##  - velocidades legadas sao px/frame @60fps: godot_px_s = legado * 60 * TILE_SCALE
##  - raios/distancias em px (HONEY_R, POISON_RADIUS, COLLECT_R, r dos morcegos, size dos
##    fantasmas...): godot_px = legado * TILE_SCALE
##  - valores em CELULAS e TEMPOS (s/ms) NAO mudam.
## O balanceamento e intocavel: todo numero vem de data/legacy/*.json e so passa por aqui.

const LEGACY_TILE: int = 36
const TILE: int = 32
const TILE_SCALE: float = 32.0 / 36.0
const LEGACY_FPS: float = 60.0
const COLS: int = 18
const ROWS: int = 30
const WORLD_W: int = COLS * TILE  # 576
const WORLD_H: int = ROWS * TILE  # 960


## Velocidade legada (px/frame @60fps) -> px/s no Godot.
static func speed_px_frame_to_px_s(legacy_px_per_frame: float) -> float:
	return legacy_px_per_frame * LEGACY_FPS * TILE_SCALE


## Raio/distancia legada em px -> px do Godot.
static func px(legacy_px: float) -> float:
	return legacy_px * TILE_SCALE


## Celula (coluna, linha) -> posicao do centro da celula em px do mundo.
static func cell_center(c: int, r: int) -> Vector2:
	return Vector2((c + 0.5) * TILE, (r + 0.5) * TILE)


## Posicao em px do mundo -> celula (coluna, linha).
static func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))
