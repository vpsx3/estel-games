class_name WorldView
extends Node2D
## Visual minimo (placeholder, sem arte nova; arte final = E8) das camadas de mundo da run:
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


func _draw_collectibles() -> void:
	if run.buffs == null:
		return
	var font: Font = ThemeDB.fallback_font
	var r: float = Units.px(13.0)
	for col: Dictionary in (run.buffs as BuffSystem).collectibles:
		var rar: String = str(col["rar"])
		var rare: bool = rar == "raro"
		var amp: float = 0.18 if rare else 0.08
		var pulse: float = 1.0 + sin(run.elapsed * (7.0 if rare else 4.0) + float(col["born"])) * amp
		var life: float = float(col["life"])
		var fade: float = (0.4 + 0.6 * absf(sin(run.elapsed * 8.0))) if life < 2.5 else 1.0
		var tint: Color = Color(BuffSystem.rarity_color(rar))
		tint.a = fade
		var pos: Vector2 = col["pos"] as Vector2
		if rare:   # aneis girando
			var rot: float = run.elapsed * 2.2
			for k in 3:
				var a: float = rot + k * TAU / 3.0
				draw_arc(pos, (r + Units.px(7.0)) * pulse, a, a + 0.8, 8, Color(1.0, 0.59, 0.59, 0.45 * fade), 2.0)
		draw_circle(pos, r * pulse, Color(0.08, 0.11, 0.19, 0.92 * fade))
		draw_arc(pos, r * pulse, 0.0, TAU, 20, tint, 2.0)
		var letter: String = str(col["id"]).substr(0, 1).to_upper()
		draw_string(font, pos + Vector2(-4, 5), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, fade))


func _draw_honey() -> void:
	var rr: float = Units.px(GameplayLits.c("HONEY_R"))
	for h: Dictionary in run.honey.drops:
		var fade: float = (0.4 + 0.6 * absf(sin(run.elapsed * 8.0))) if float(h["life"]) < 2.5 else 1.0
		var pulse: float = 1.0 + sin(run.elapsed * 4.0 + float(h["born"])) * 0.08
		draw_circle(h["pos"] as Vector2, rr * pulse, Color(1.0, 0.82, 0.25, 0.9 * fade))
		draw_arc(h["pos"] as Vector2, rr * pulse, 0.0, TAU, 16, Color(0.6, 0.35, 0.05, fade), 2.0)


func _draw_decoy() -> void:
	if run.decoy == null:
		return
	var p: Vector2 = (run.decoy as Dictionary)["pos"] as Vector2
	var a: float = 0.55 + 0.2 * sin(run.elapsed * 6.0)
	draw_circle(p, Units.px(14.0), Color(0.78, 0.52, 0.23, a))
	draw_arc(p, Units.px(24.0), 0.0, TAU, 20, Color(1.0, 0.8, 0.53, a), 1.5)


func _draw_notifications() -> void:
	var font: Font = ThemeDB.fallback_font
	for n: Dictionary in run.notifications:
		var c: Color = Color(str(n["color"]))
		c.a = clampf(float(n["life"]) / float(n["max_life"]), 0.0, 1.0)
		draw_string(font, n["pos"] as Vector2, str(n["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(n["size"]), c)
