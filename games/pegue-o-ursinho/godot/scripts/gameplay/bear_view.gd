class_name BearView
extends Node2D
## Visual do urso (placeholder: spritesheet legado 4 direcoes). Segue BearModel; sem logica de jogo.
## Porta os modificadores de drawBear: invisivel 0.4, congelado 0.6, invulneravel pisca, pulo scale y 0.8.

const SHEET_CELL: float = 64.0   # BEAR_CELL_W/H do JS

var model: BearModel
var run: GameRun
@onready var sprite: Sprite2D = $Sprite


func bind(p_run: GameRun) -> void:
	run = p_run
	model = p_run.bear


func _process(_dt: float) -> void:
	if run == null:
		return
	model = run.bear
	position = model.pos
	var cols: Dictionary = GameState.constants["BEAR_DIR_COL"] as Dictionary
	var col: int = int(cols.get(model.facing, 1))
	sprite.region_rect = Rect2(col * SHEET_CELL, 0, SHEET_CELL, SHEET_CELL)
	var draw_size: float = model.size * GameplayLits.c("BEAR_DRAW_MULT")
	var s: float = draw_size / SHEET_CELL
	sprite.scale = Vector2(s, s * (0.8 if run.jump.active else 1.0))
	var a: float = 1.0
	if run.invisible_timer > 0.0:
		a = 0.4
	if model.frozen > 0.0:
		a = 0.6
	if model.invuln > 0.0:
		a = 0.5 + 0.5 * absf(sin(run.elapsed * 18.0))
	sprite.modulate = Color(1, 1, 1, a)
