class_name GhostView
extends Node2D
## Visual do fantasma: AnimatedSprite2D com SpriteFrames por classe (assets/actors/ghosts/<classe>_frames.tres,
## animacoes float_<south|north|east|west>), escala 1:1, centrado em model.pos. A direcao vem de model.facing
## (o modelo ja a calcula do vetor de movimento). Sem logica de jogo.
## Estados: congelado = tom azulado + alfa; preso = tom roxo; impulso (boost) = brilho quente; lento = tom frio.
## Os overlays de gelo/prisao/lento/aura sao do VfxDirector.

const DIRS: Array = ["south", "north", "east", "west"]
const FRAMES_DIR: String = "res://assets/actors/ghosts/"
static var _cache: Dictionary = {}

var model: GhostModel
var _tipo: String = ""
var _anim: String = ""
@onready var sprite: AnimatedSprite2D = $Sprite


static func frames_for(tipo: String) -> SpriteFrames:
	if not _cache.has(tipo):
		_cache[tipo] = load(FRAMES_DIR + tipo + "_frames.tres") as SpriteFrames
	return _cache[tipo] as SpriteFrames


func bind(g: GhostModel) -> void:
	model = g


func _process(_dt: float) -> void:
	if model == null:
		return
	position = model.pos
	if model.tipo != _tipo:
		_tipo = model.tipo
		sprite.sprite_frames = frames_for(_tipo)
		_anim = ""
	var d: String = model.facing if DIRS.has(model.facing) else "south"
	var a: String = "float_" + d
	if a != _anim:
		var f: int = sprite.frame
		var p: float = sprite.frame_progress
		_anim = a
		sprite.play(a)
		if f > 0 or p > 0.0:   # mantem a fase do bob ao virar de direcao
			sprite.set_frame_and_progress(f, p)
		elif model.palette_index > 0:   # fases diferentes entre fantasmas
			sprite.set_frame_and_progress(model.palette_index % 6, 0.0)
	var tint: Color = _state_tint()
	tint.a *= self_modulate.a   # alfa global (game.gd define self_modulate.a)
	sprite.modulate = tint


func _state_tint() -> Color:
	if model.trapped > 0.0:
		return Color(0.82, 0.62, 1.0, 0.7)
	if model.frozen > 0.0:
		return Color(0.62, 0.86, 1.0, 0.75)
	if model.boost_timer > 0.0:
		var k: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		return Color(1.0, 0.85 + 0.1 * k, 0.65 + 0.1 * k, 1.0)
	return Color.WHITE
