extends "res://tests/case.gd"
## QA E10 (F1/F4): guardas comportamentais contra regressao silenciosa de literais de GameplayLits
## (PUSH_CELLS, GEYSER_FIRE_AT, VOID_PORTAL_AWAY_CELLS, TELEPORT_MIN_CELLS) + efeito CERTO do VfxDirector
## + icones de bioma resolvendo para arquivos reais. Os valores esperados sao os do legado (index.html):
## pushGhost TILE*1.6; mechGeyserState sin>0.6; mechUpdateVoid portal >= 8 celulas; applyMapBuff teleport 6 celulas.

const F: GDScript = preload("res://tests/support/run_factory.gd")
const LEGACY_PUSH_CELLS: float = 1.6
const LEGACY_GEYSER_FIRE_AT: float = 0.6
const LEGACY_PORTAL_AWAY_CELLS: float = 8.0
const LEGACY_TELEPORT_MIN_CELLS: float = 6.0
const TRIALS: int = 150


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_lits_match_legacy() -> void:
	near(GameplayLits.PUSH_CELLS, LEGACY_PUSH_CELLS, "PUSH_CELLS")
	near(GameplayLits.GEYSER_FIRE_AT, LEGACY_GEYSER_FIRE_AT, "GEYSER_FIRE_AT")
	near(GameplayLits.VOID_PORTAL_AWAY_CELLS, LEGACY_PORTAL_AWAY_CELLS, "VOID_PORTAL_AWAY_CELLS")
	near(GameplayLits.TELEPORT_MIN_CELLS, LEGACY_TELEPORT_MIN_CELLS, "TELEPORT_MIN_CELLS")


## Empurrao de captura: o fantasma anda exatamente TILE*1.6 para longe do urso.
func test_push_ghost_moves_exact_cells() -> void:
	var run: GameRun = F.make_run(1, true)
	run.bear.pos = Units.cell_center(8, 14)
	var g: GhostModel = run.ghost_sys.make_ghost("comum", run.bear.pos + Vector2(Units.TILE * 2.0, 0.0))
	run.ghost_sys.ghosts.append(g)
	var before: Vector2 = g.pos
	run.ghost_sys.push_ghost(g)
	near(g.pos.distance_to(before), Units.TILE * LEGACY_PUSH_CELLS, "deslocamento = TILE*1.6", 0.01)
	check(g.pos.x > before.x and absf(g.pos.y - before.y) < 0.01, "empurra para longe do urso")


## Momento da erupcao do geiser: fase 0, sin(t*geySpeed) cruza 0.6 em t = asin(0.6)/geySpeed.
func test_geyser_eruption_moment() -> void:
	var run: GameRun = F.make_mech_run(8, true, 9)
	var m: MechFire = run.mech as MechFire
	var speed: float = m.cfg_f("geySpeed")
	near(speed, 0.8, "geySpeed legado")
	m.geysers = [{"cell": Vector2i(6, 12), "phase": 0.0}]
	var th: float = asin(LEGACY_GEYSER_FIRE_AT)
	run.elapsed = (th - 0.02) / speed
	eq(m.geyser_state(m.geysers[0]), "warming", "antes do limiar 0.6 ainda nao e fogo")
	run.elapsed = (th + 0.02) / speed
	eq(m.geyser_state(m.geysers[0]), "fire", "depois do limiar 0.6 e fogo")
	# janela de fogo = [asin(.6), PI - asin(.6)]: progresso 0.5 no pico
	run.elapsed = (PI / 2.0) / speed
	near(m.fire_progress(m.geysers[0]), 0.5, "pico da janela de fogo = 0.5", 0.001)
	run.elapsed = (PI - th - 0.02) / speed
	eq(m.geyser_state(m.geysers[0]), "fire", "ainda fogo logo antes do fim")
	run.elapsed = (PI - th + 0.02) / speed
	eq(m.geyser_state(m.geysers[0]), "warming", "fim da janela de fogo simetrico")


## Portal do vazio: destino sempre > 8 celulas da origem (e o limiar nao e maior que 8).
func test_void_portal_distance() -> void:
	var run: GameRun = F.make_mech_run(9, true, 7)
	var m: MechVoid = run.mech as MechVoid
	var cell: Vector2i = Vector2i(1, 1)
	var origin: Vector2 = Units.cell_center(cell.x, cell.y)
	var lo: float = INF
	for i in TRIALS:
		m.portals = [cell]
		m.portal_cd = 0.0
		run.bear.pos = origin
		m.update(run, 1.0 / 60.0)
		lo = minf(lo, run.bear.pos.distance_to(origin))
		check(m.portal_cd > 0.0, "portal disparou")
	check(lo > Units.TILE * LEGACY_PORTAL_AWAY_CELLS, "portal sempre > 8 celulas (min=%.1f px)" % lo)
	check(lo < Units.TILE * (LEGACY_PORTAL_AWAY_CELLS + 1.0), "limiar nao e maior que 8 celulas (min=%.1f px)" % lo)


## Teleporte: destino > 6 celulas do fantasma mais proximo (e o limiar nao e maior que 6).
func test_teleport_min_distance() -> void:
	var lo: float = INF
	for i in TRIALS:
		var run: GameRun = F.make_full(1000 + i)
		var g: GhostModel = run.ghosts[0]
		g.pos = Units.cell_center(1, 1)
		run.ghosts.resize(1)
		(run.buffs as BuffSystem).apply_map_buff("teleport")
		lo = minf(lo, run.bear.pos.distance_to(g.pos))
	check(lo > Units.TILE * LEGACY_TELEPORT_MIN_CELLS, "teleporte sempre > 6 celulas (min=%.1f px)" % lo)
	check(lo < Units.TILE * (LEGACY_TELEPORT_MIN_CELLS + 1.0), "limiar nao e maior que 6 celulas (min=%.1f px)" % lo)


# ---------------------------------------------------------------- VfxDirector
func _vfx_ids(host: Node) -> Array:
	var out: Array = []
	for c: Node in host.get_children():
		if c is VfxPlayer and not c.is_queued_for_deletion():
			out.append((c as VfxPlayer).vfx_id)
	out.sort()
	return out


func _clear(host: Node) -> void:
	for c: Node in host.get_children():
		if c is VfxPlayer:
			host.remove_child(c)
			c.free()


func test_vfx_director_right_effect_per_event() -> void:
	var run: GameRun = F.make_full(5)
	var host: Node2D = Node2D.new()
	_tree().root.add_child(host)
	var d: VfxDirector = VfxDirector.new()
	d.bind(run, host)
	host.add_child(d)
	d._process(0.0)   # semeia estado (fantasmas existentes nao disparam ghost_spawn)
	_clear(host)

	Events.bear_jumped.emit()
	eq(_vfx_ids(host), ["jump"], "pulo -> jump")
	_clear(host)

	Events.buff_activated.emit("freeze_all")
	eq(_vfx_ids(host), ["freeze_all"], "buff freeze_all -> freeze_all")
	_clear(host)

	Events.buff_activated.emit("teleport")
	eq(_vfx_ids(host), ["teleport"], "buff teleport -> teleport")
	_clear(host)

	Events.buff_activated.emit("light_bomb")
	eq(_vfx_ids(host), ["light_bomb"], "buff light_bomb -> light_bomb")
	_clear(host)

	Events.honey_collected.emit(5)
	eq(_vfx_ids(host), ["honey_pickup"], "mel -> honey_pickup")
	_clear(host)

	Events.biome_changed.emit(1)
	eq(_vfx_ids(host), ["biome_transition"], "bioma -> biome_transition")
	_clear(host)

	run.shield_charges = 1
	d._process(0.0)
	eq(_vfx_ids(host), ["shield"], "escudo ativo -> shield (loop)")
	run.shield_charges = 0
	d._process(0.0)
	check("shield_break" in _vfx_ids(host), "escudo quebrado -> shield_break")
	_clear(host)
	d._process(0.0)
	_clear(host)

	run.bear.poisoned = true
	d._process(0.0)
	eq(_vfx_ids(host), ["poisoned"], "veneno -> poisoned")
	run.bear.poisoned = false
	d._process(0.0)
	_clear(host)

	Events.game_over.emit({})
	eq(_vfx_ids(host), ["caught"], "captura/game over -> caught")

	host.queue_free()
	await _tree().process_frame


# ---------------------------------------------------------------- icones de bioma (F1)
func test_biome_icon_keys_resolve_to_files() -> void:
	for b in 10:
		var key: String = "biome_%02d" % (b + 1)   # chave usada por hud.gd (banner/icone de bioma)
		var path: String = UiIcons.DIR + str(UiIcons.ALIAS.get(key, key)) + ".png"
		check(ResourceLoader.exists(path), "arquivo de icone existe: " + path)
		var tr: TextureRect = TextureRect.new()
		UiIcons.apply(tr, key, UiIcons.color_for(key), "B")
		check(not tr.has_meta("placeholder"), "sem placeholder: " + key)
		tr.free()
	# nenhum script de UI pode montar chave de bioma sem zero a esquerda
	var dir: DirAccess = DirAccess.open("res://scripts/ui")
	for f: String in dir.get_files():
		if f.ends_with(".gd"):
			var src: String = FileAccess.get_file_as_string("res://scripts/ui/" + f)
			check(not ("\"biome_%d\"" in src), "%s nao usa chave biome_%%d" % f)
	var hud: String = FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	check("\"biome_%02d\" % (b + 1)" in hud, "hud.gd usa biome_%02d")
	var res: String = FileAccess.get_file_as_string("res://scripts/ui/result_screen.gd")
	check(not ("biome_icon" in res or "UiIcons.apply(%Biome" in res), "result_screen nao usa icone de bioma")
