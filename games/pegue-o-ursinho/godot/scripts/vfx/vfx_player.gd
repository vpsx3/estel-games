class_name VfxPlayer
extends Node2D
## Efeito generico (assets/vfx/<id>/<id>_frames.tres, clip "whole" do PixelLab).
## One-shot (loop=false no .tres): toca e se autodestroi. Loop: toca ate stop_effect().
## `loop_forever` = repete um one-shot ate stop_effect() (estados longos, ex.: preso/congelado).
## O no fica na ANCORA do efeito (metadata anchor: "feet" = pes do ator, "origin" = centro) e o sprite
## e deslocado por metadata/offset (do effect.json). `follow` = objeto com `pos` (BearModel/GhostModel).
##
## Uso:  VfxPlayer.spawn(host, "jump", {"pos": p})
##       VfxPlayer.spawn(host, "shield", {"follow": bear_model, "follow_dy": 21.0})

const SCENE: PackedScene = preload("res://scenes/vfx/vfx_player.tscn")
const DIR: String = "res://assets/vfx/"

var vfx_id: String = ""
var loop_forever: bool = false
var follow: Object = null
var follow_dy: float = 0.0
var flip: bool = false
var _sprite: AnimatedSprite2D
var _offset: Vector2 = Vector2.ZERO
var _frame_w: float = 0.0
var _stopping: bool = false


## Cria e adiciona ao `host`. opts: pos, follow, follow_dy, loop (forcar repeticao), flip, scale,
## modulate, z, speed. Retorna null se o efeito nao existir.
static func spawn(host: Node, id: String, opts: Dictionary = {}) -> VfxPlayer:
	var path: String = DIR + id + "/" + id + "_frames.tres"
	if not ResourceLoader.exists(path):
		return null
	var fx: VfxPlayer = SCENE.instantiate() as VfxPlayer
	fx.vfx_id = id
	fx.loop_forever = bool(opts.get("loop", false))
	fx.follow = opts.get("follow", null) as Object
	fx.follow_dy = float(opts.get("follow_dy", 0.0))
	fx.flip = bool(opts.get("flip", false))
	fx.position = opts.get("pos", Vector2.ZERO) as Vector2
	fx.scale = opts.get("scale", Vector2.ONE) as Vector2
	fx.modulate = opts.get("modulate", Color.WHITE) as Color
	fx.z_index = int(opts.get("z", 5))
	fx.set_meta("speed", float(opts.get("speed", 1.0)))
	host.add_child(fx)
	return fx


func _ready() -> void:
	_sprite = $Sprite as AnimatedSprite2D
	var sf: SpriteFrames = load(DIR + vfx_id + "/" + vfx_id + "_frames.tres") as SpriteFrames
	_sprite.sprite_frames = sf
	_offset = sf.get_meta("offset", Vector2.ZERO) as Vector2
	_frame_w = float(sf.get_frame_texture("default", 0).get_width())
	_apply_flip()
	_sprite.speed_scale = float(get_meta("speed", 1.0))
	_sprite.animation_finished.connect(_on_finished)
	_sprite.play("default")
	_sync()


func set_flip(f: bool) -> void:
	if f != flip:
		flip = f
		_apply_flip()


func _apply_flip() -> void:
	if _sprite == null:
		return
	_sprite.flip_h = flip
	# espelha em torno da ancora: o retangulo do frame passa a [-(off.x + w), ...]
	_sprite.offset = Vector2(-(_offset.x + _frame_w) if flip else _offset.x, _offset.y)


func _process(_dt: float) -> void:
	_sync()


func _sync() -> void:
	if follow != null:
		position = (follow.get("pos") as Vector2) + Vector2(0.0, follow_dy)


func _on_finished() -> void:
	if loop_forever and not _stopping:
		_sprite.play("default")
	else:
		queue_free()


## Encerra um efeito em loop (fade rapido) e libera o no.
func stop_effect() -> void:
	if _stopping:
		return
	_stopping = true
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)
