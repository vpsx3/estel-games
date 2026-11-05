class_name GhostModel
extends RefCounted
## Dados de um fantasma (objeto de makeGhost). speed em unidade LEGADA (px/frame @60fps,
## ja multiplicada por getDiffMult); size em px do Godot. Timers *_ms em milissegundos como no JS.

var pos: Vector2 = Vector2.ZERO
var speed: float = 0.0
var base_speed: float = 0.0
var base_class_speed: float = 0.0
var size: float = 0.0
var tipo: String = "comum"
# Ganchos para buffs (E4b): congelado, preso (spirit_trap), impulso (fantasma roubou buff).
var frozen: float = 0.0
var trapped: float = 0.0
var boost_timer: float = 0.0
var boost_mult: float = 1.0
var facing: String = "south"
var palette_index: int = 0
# errante
var is_chasing: bool = false
var mode_timer: float = 0.0
var wander_dir: Vector2 = Vector2.RIGHT
var wander_timer: float = GameplayLits.WANDER_RETARGET_MS
# venenoso
var poison_timer: float = 0.0
