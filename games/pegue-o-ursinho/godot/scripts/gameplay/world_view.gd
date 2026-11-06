class_name WorldView
extends Node2D
## Visual das camadas de mundo da run:
##   mode "under": mecanica (draw_under), orbes de buff, potes de mel, isca  -> abaixo dos atores
##   mode "over" : mecanica (draw_over) e notificacoes flutuantes            -> acima dos atores
## Mesma ordem de desenho do gameLoop: drawMap, mechDrawUnder, drawCollectibles, drawHoney,
## drawDecoy, fantasmas, urso, mechDrawOver, drawNotifications.

@export_enum("under", "over") var mode: String = "under"

var run: GameRun


func bind(r: GameRun) -> void:
	run = r


var _mech_seen: Object = null


func _process(_dt: float) -> void:
	var m: Object = run.mech if run != null else null
	if m != _mech_seen:   # mecanica nova (troca de bioma/run): refaz os nos auxiliares (ex.: agua com shader)
		for c: Node in get_children():
			c.queue_free()
		_mech_seen = m
		if m != null and mode == "under" and m.has_method("attach_nodes"):
			m.call("attach_nodes", self)
	queue_redraw()


func _draw() -> void:
	if run == null:
		return
	if mode == "under":
		if run.mech != null and run.mech.has_method("draw_under"):
			run.mech.call("draw_under", self)
		_draw_collectibles()
		_draw_honey()
		_draw_decoy()
	else:
		if run.mech != null and run.mech.has_method("draw_over"):
			run.mech.call("draw_over", self)
		_draw_notifications()


const ORB_BY_RARITY: Dictionary = {"comum": "buff_orb_verde", "incomum": "buff_orb_azul", "raro": "buff_orb_vermelho"}
const ICON_PX: float = 16.0
static var _sf_cache: Dictionary = {}
static var _icon_cache: Dictionary = {}


static func _sf(path: String) -> SpriteFrames:
	if not _sf_cache.has(path):
		_sf_cache[path] = load(path) as SpriteFrames
	return _sf_cache[path] as SpriteFrames


## Frame (textura, indice) da animacao no instante t (s), em loop.
static func _frame(sf: SpriteFrames, anim: String, t: float) -> Array:
	var n: int = sf.get_frame_count(anim)
	var i: int = posmod(int(floor(maxf(t, 0.0) * sf.get_animation_speed(anim))), n)
	return [sf.get_frame_texture(anim, i), i]


## Icone do buff (assets/ui/icons/<id>.png, do ui-artist); null se ainda nao existir.
static func _icon(id: String) -> Texture2D:
	if not _icon_cache.has(id):
		var path: String = "res://assets/ui/icons/%s.png" % id
		_icon_cache[id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _icon_cache[id] as Texture2D


func _draw_tex(tex: Texture2D, center: Vector2, scale_f: float, tint: Color) -> void:
	var sz: Vector2 = tex.get_size() * scale_f
	draw_texture_rect(tex, Rect2(center - sz * 0.5, sz), false, tint)


func _draw_collectibles() -> void:
	if run.buffs == null:
		return
	var r: float = Units.px(13.0)
	for col: Dictionary in (run.buffs as BuffSystem).collectibles:
		var rar: String = str(col["rar"])
		var rare: bool = rar == "raro"
		var amp: float = 0.18 if rare else 0.08
		var pulse: float = 1.0 + sin(run.elapsed * (7.0 if rare else 4.0) + float(col["born"])) * amp
		var life: float = float(col["life"])
		var fade: float = (0.4 + 0.6 * absf(sin(run.elapsed * 8.0))) if life < 2.5 else 1.0
		var pos: Vector2 = col["pos"] as Vector2
		if rare:   # aneis girando
			var rot: float = run.elapsed * 2.2
			for k in 3:
				var a: float = rot + k * TAU / 3.0
				draw_arc(pos, (r + Units.px(7.0)) * pulse, a, a + 0.8, 8, Color(1.0, 0.59, 0.59, 0.45 * fade), 2.0)
		if str(col["type"]) == "passive":   # halo dourado dos passivos (HTML: contorno #ffd84d)
			draw_arc(pos, r * pulse + 1.0, 0.0, TAU, 20, Color(1.0, 0.85, 0.3, 0.9 * fade), 1.5)
		var sf: SpriteFrames = _sf("res://assets/collectibles/%s/%s_frames.tres" % [ORB_BY_RARITY.get(rar, "buff_orb_verde"), ORB_BY_RARITY.get(rar, "buff_orb_verde")])
		var fr: Array = _frame(sf, "pulse", run.elapsed + float(col["born"]) * 0.2)
		var fs: PackedFloat32Array = sf.get_meta("frame_scale", PackedFloat32Array()) as PackedFloat32Array
		var k_frame: float = fs[int(fr[1])] if fs.size() > int(fr[1]) else 1.0
		_draw_tex(fr[0] as Texture2D, pos, pulse * k_frame, Color(1, 1, 1, fade))
		var ic: Texture2D = _icon(str(col["id"]))   # emoji do HTML -> icone aprovado
		if ic != null:
			var isz: Vector2 = Vector2(ICON_PX, ICON_PX) * pulse
			draw_texture_rect(ic, Rect2(pos - isz * 0.5, isz), false, Color(1, 1, 1, fade))
		# TODO(ui-artist): ids sem icone em assets/ui/icons/ aparecem so como orbe.


func _draw_honey() -> void:
	var sf: SpriteFrames = _sf("res://assets/collectibles/honey_pot/honey_pot_frames.tres")
	for h: Dictionary in run.honey.drops:
		var fade: float = (0.4 + 0.6 * absf(sin(run.elapsed * 8.0))) if float(h["life"]) < 2.5 else 1.0
		var fr: Array = _frame(sf, "sparkle", run.elapsed + float(h["born"]) * 0.3)
		_draw_tex(fr[0] as Texture2D, h["pos"] as Vector2, 1.0, Color(1, 1, 1, fade))


func _draw_decoy() -> void:
	if run.decoy == null:
		return
	var p: Vector2 = (run.decoy as Dictionary)["pos"] as Vector2
	var a: float = 0.8 + 0.15 * sin(run.elapsed * 6.0)
	var sf: SpriteFrames = _sf("res://assets/actors/decoy/decoy_frames.tres")
	_draw_tex(_frame(sf, "wobble", run.elapsed)[0] as Texture2D, p, 1.0, Color(1, 1, 1, a))
	draw_arc(p, Units.px(24.0), 0.0, TAU, 20, Color(1.0, 0.8, 0.53, a * 0.5), 1.0)


func _draw_notifications() -> void:
	var font: Font = ThemeDB.fallback_font
	for n: Dictionary in run.notifications:
		var c: Color = Color(str(n["color"]))
		c.a = clampf(float(n["life"]) / float(n["max_life"]), 0.0, 1.0)
		draw_string(font, n["pos"] as Vector2, str(n["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(n["size"]), c)
