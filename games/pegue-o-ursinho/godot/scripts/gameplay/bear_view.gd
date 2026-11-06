class_name BearView
extends Node2D
## Visual do urso: AnimatedSprite2D com assets/actors/bear/bear_frames.tres (PixelLab cand_b, canvas 64
## com o corpo centrado em model.pos: offset -8). Escala 1:1 (48 px). Segue BearModel; sem logica de jogo.
## Animacao pelo estado: caught (run perdida) > celebrate (novo bioma) > jump_<dir> > dash/walk_<dir> > idle_<dir>.
## Modificadores: invisivel a=0.45 (o overlay vem do VfxDirector), congelado 0.6, invulneravel pisca.

const FEET_DY: float = 21.0       ## pes do sprite abaixo de model.pos (VfxDirector ancora efeitos "feet" aqui)
const SHADOW_COLOR: Color = Color(0.19, 0.01, 0.03, 0.28)

var model: BearModel
var run: GameRun
var _anim: String = ""
var _dash_on: bool = false
var _celebrate_left: float = 0.0
@onready var sprite: AnimatedSprite2D = $Sprite


func bind(p_run: GameRun) -> void:
	run = p_run
	model = p_run.bear
	if not Events.buff_activated.is_connected(_on_buff):
		Events.buff_activated.connect(_on_buff)
	if not Events.biome_announce.is_connected(_on_announce):
		Events.biome_announce.connect(_on_announce)


func _exit_tree() -> void:
	if Events.buff_activated.is_connected(_on_buff):
		Events.buff_activated.disconnect(_on_buff)
	if Events.biome_announce.is_connected(_on_announce):
		Events.biome_announce.disconnect(_on_announce)


func _on_buff(id: String) -> void:
	if id == "dash":
		_dash_on = true


func _on_announce(_biome: int) -> void:
	_celebrate_left = 0.9   # ~9 frames @10 fps


func _draw() -> void:
	# sombra projetada so no Godot (biblia: elipse pequena, nao pintada no sprite)
	draw_set_transform(Vector2(0, FEET_DY - 2.0), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 11.0, SHADOW_COLOR)


func _process(dt: float) -> void:
	if run == null:
		return
	model = run.bear
	position = model.pos
	if run.bear_boost_timer <= 0.0:
		_dash_on = false
	_celebrate_left = maxf(0.0, _celebrate_left - dt)
	_play(_pick_animation())
	var a: float = 1.0
	if run.invisible_timer > 0.0:
		a = 0.45
	if model.frozen > 0.0:
		a = 0.6
	if model.invuln > 0.0:
		a = 0.5 + 0.5 * absf(sin(run.elapsed * 18.0))
	sprite.modulate = Color(1, 1, 1, a)


func _pick_animation() -> String:
	var d: String = model.facing if model.facing in ["south", "north", "east", "west"] else "south"
	if run.state == "lose":
		return "caught"
	if _celebrate_left > 0.0 and not run.jump.active:
		return "celebrate"
	if run.jump.active:
		return "jump_" + d
	if model.moving and model.frozen <= 0.0:
		return ("dash_" if _dash_on else "walk_") + d
	return "idle_" + d


func _play(want: String) -> void:
	if want == _anim:
		return
	var same_family: bool = _anim != "" and _anim.get_slice("_", 0) == want.get_slice("_", 0) and want.contains("_")
	var keep_frame: int = sprite.frame
	var keep_prog: float = sprite.frame_progress
	_anim = want
	sprite.play(want)
	if same_family:   # troca so de direcao: mantem o ponto da animacao
		sprite.set_frame_and_progress(keep_frame, keep_prog)
	# pulo: a animacao inteira dura o pulo do modelo (JUMP_DURATION + atributos)
	var spd: float = 1.0
	if want.begins_with("jump_") and run.jump.duration > 0.0:
		var sf: SpriteFrames = sprite.sprite_frames
		spd = (float(sf.get_frame_count(want)) / sf.get_animation_speed(want)) / run.jump.duration
	sprite.speed_scale = spd
