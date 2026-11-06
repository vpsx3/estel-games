class_name MechVoid
extends MechBase
## Dimensao dos Fantasmas: inversao de fases + portais (bioma 9). Porta mechInitVoid /
## mechUpdateVoid / mechGhostAlpha / mechDrawVoidUnder / mechDrawVoidOver.
## Ciclo: normal (period-dur) -> 'phase' (atravessa paredes, reusa phase_timer) -> normal -> 'blind'
## (fantasmas a 15% de alpha) -> ... O "mapa respira" (overlay das paredes) fica para o E8.

var invert_mode: String = "normal"   # normal | phase | blind
var invert_timer: float = 0.0
var next_special: String = "phase"
var flash: float = 0.0
var portals: Array[Vector2i] = []
var portal_cd: float = 0.0


func setup() -> void:
	invert_mode = "normal"
	invert_timer = cfg_f("invertPeriod") - cfg_f("invertDur")
	next_special = "phase"
	flash = 0.0
	portal_cd = 0.0
	var hand: Array = markers(["portal"])
	if not hand.is_empty():
		for n in hand:
			portals.append(marker_cell(n))
		hide_markers(hand)
		return
	for cell: Vector2i in pick_random(GridCollision.free_cells(run.level), int(cfg_f("portals"))):
		portals.append(cell)


func update(r: GameRun, dt: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - dt)
	invert_timer -= dt
	if invert_timer <= 0.0:
		if invert_mode == "normal":
			invert_mode = next_special
			next_special = "blind" if next_special == "phase" else "phase"
			invert_timer = cfg_f("invertDur")
		else:
			invert_mode = "normal"
			invert_timer = cfg_f("invertPeriod") - cfg_f("invertDur")
		flash = GameplayLits.VOID_FLASH_SWAP
	if invert_mode == "phase":
		r.phase_timer = maxf(r.phase_timer, GameplayLits.VOID_PHASE_KEEP)   # atravessa paredes
	if portal_cd > 0.0:
		portal_cd = maxf(0.0, portal_cd - dt)
	var bc: Vector2i = bear_cell()
	if portal_cd <= 0.0:
		for p in portals:
			if p == bc:
				r.bear.pos = r.random_free_pos_away(r.bear.pos, Units.TILE * GameplayLits.VOID_PORTAL_AWAY_CELLS)
				r.bear.landing_target = null
				portal_cd = cfg_f("portalCd")
				flash = GameplayLits.VOID_FLASH_PORTAL
				break


func ghost_alpha() -> float:
	return GameplayLits.VOID_BLIND_GHOST_ALPHA if invert_mode == "blind" else 1.0


func draw_under(ci: CanvasItem) -> void:
	for p in portals:
		draw_tex(ci, frame_at("portal", "default", run.elapsed), Units.cell_center(p.x, p.y),
			Color(0.7, 0.31, 1.0, 0.95), Color(1, 1, 1, 0.8 + 0.2 * sin(run.elapsed * 4.0)))


func draw_over(ci: CanvasItem) -> void:
	if flash > 0.0:   # flash branco rapido a cada troca de fase
		ci.draw_rect(Rect2(-32, -32, Units.WORLD_W + 64, Units.WORLD_H + 64), Color(1, 1, 1, minf(0.55, flash * 2.0)))
