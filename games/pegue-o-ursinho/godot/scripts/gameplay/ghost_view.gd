class_name GhostView
extends Node2D
## Visual do fantasma (placeholder: spritesheet legado 5 classes x 4 direcoes, celula 280).
## drawSize = size * 4 (como drawGhost). Sem logica de jogo.

const SHEET_CELL: float = 280.0

var model: GhostModel
@onready var sprite: Sprite2D = $Sprite


func bind(g: GhostModel) -> void:
	model = g


func _process(_dt: float) -> void:
	if model == null:
		return
	position = model.pos
	var rows: Dictionary = GameState.constants["GHOST_SPRITE_ROW"] as Dictionary
	var cols: Dictionary = GameState.constants["GHOST_DIR_COL"] as Dictionary
	var row: int = int(rows.get(model.tipo, 0))
	var col: int = int(cols.get(model.facing, 0))
	sprite.region_rect = Rect2(col * SHEET_CELL, row * SHEET_CELL, SHEET_CELL, SHEET_CELL)
	var s: float = model.size * 4.0 / SHEET_CELL
	sprite.scale = Vector2(s, s)
	sprite.modulate = Color(1, 1, 1, 0.6 if model.frozen > 0.0 else 1.0)
