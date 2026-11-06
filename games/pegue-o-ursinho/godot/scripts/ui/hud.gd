class_name Hud
extends UiScreen
## HUD da run (ui/uiRight/honeyHud/passiveHud/fxHud + drawBiomeWarning/drawBiomeAnnounce do HTML).
## Le o estado de game.run / game.buffs todo frame (update_from()). Botao de pausa sempre visivel.
## Nos: TimerLabel, GhostIcon/GhostCountLabel, HoneyIcon/HoneyLabel, BiomeLabel, PauseButton,
## PassiveList (PassiveChip), FxList (FxChip), WarningLabel, Banner (BiomeIcon/BannerName/BannerSub).

signal pause_pressed

const FX_CHIP: PackedScene = preload("res://scenes/ui/fx_chip.tscn")
const PASSIVE_CHIP: PackedScene = preload("res://scenes/ui/passive_chip.tscn")
# Maximos literais do JS (barra de congelados/presos): activeEffects().
const FROZEN_MAX: float = 4.0
const TRAPPED_MAX: float = 5.0

@onready var timer_label: Label = %TimerLabel
@onready var ghost_count_label: Label = %GhostCountLabel
@onready var honey_label: Label = %HoneyLabel
@onready var biome_label: Label = %BiomeLabel
@onready var pause_button: Button = %PauseButton
@onready var passive_list: HBoxContainer = %PassiveList
@onready var fx_list: VBoxContainer = %FxList
@onready var warning_label: Label = %WarningLabel
@onready var banner: Control = %Banner
@onready var banner_name: Label = %BannerName
@onready var banner_sub: Label = %BannerSub

var game: Node = null
var _fx_chips: Dictionary = {}        # key -> FxChip
var _passive_chips: Dictionary = {}   # buff id -> PassiveChip


func _ready() -> void:
	super()
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	UiIcons.apply(%GhostIcon as TextureRect, "ghost", UiIcons.color_for("ghost"), "F")
	UiIcons.apply(%HoneyIcon as TextureRect, "honey", UiIcons.color_for("honey"), "M")
	UiIcons.apply(%BiomeIcon as TextureRect, "biome_01", UiIcons.color_for("biome_01"), "B")
	banner.modulate.a = 0.0
	warning_label.visible = false


func bind(p_game: Node) -> void:
	game = p_game
	clear_chips()


func _process(_dt: float) -> void:
	if game == null or not is_instance_valid(game) or not visible:
		return
	var run: GameRun = game.get("run") as GameRun
	if run != null:
		update_from(run, game.get("buffs") as BuffSystem)


func refresh() -> void:
	if game != null and is_instance_valid(game):
		var run: GameRun = game.get("run") as GameRun
		if run != null:
			update_from(run, game.get("buffs") as BuffSystem)


## Um frame da HUD a partir da simulacao.
func update_from(run: GameRun, buffs: BuffSystem) -> void:
	timer_label.text = UiText.format_time(run.elapsed)
	ghost_count_label.text = "×%d" % run.ghosts.size()
	honey_label.text = str(run.run_honey)
	var b: int = run.cycle.current_biome
	biome_label.text = "%s %d/%d - %s" % [I18n.t("world_label"), b + 1, int(GameplayLits.c("TOTAL_BIOMES")), I18n.biome_name(b)]
	_update_warning(run)
	_update_banner(run)
	_update_fx(run)
	_update_passives(buffs)


## drawBiomeWarning(): restantes > 5 => "O mundo esta mudando..."; senao "Novo mapa em N...".
func _update_warning(run: GameRun) -> void:
	var on: bool = run.cycle.phase == "warning"
	warning_label.visible = on
	if not on:
		return
	var remain: float = maxf(0.0, run.cycle.remaining(run.elapsed))
	if remain > 5.0:
		warning_label.text = I18n.t("biome_changing")
	else:
		warning_label.text = "%s%d…" % [I18n.t("biome_new_map_in"), maxi(1, ceili(remain))]
	warning_label.modulate.a = 0.85 + 0.15 * sin(run.elapsed * PI * 4.0)


## drawBiomeAnnounce(): fade-in 0.4s, fade-out 0.8s.
func _update_banner(run: GameRun) -> void:
	var timer: float = run.cycle.announce_timer
	if timer <= 0.0:
		banner.modulate.a = 0.0
		return
	var b: int = run.cycle.current_biome
	var t: float = GameplayLits.c("BIOME_ANNOUNCE_DURATION") - timer
	var alpha: float = 1.0
	if t < 0.4:
		alpha = t / 0.4
	elif timer < 0.8:
		alpha = timer / 0.8
	banner.modulate.a = clampf(alpha, 0.0, 1.0)
	banner_name.text = I18n.biome_name(b)
	var cycle_str: String = (" · %s %d" % [I18n.t("cycle_label"), run.cycle.cycle_count + 1]) if run.cycle.cycle_count > 0 else ""
	banner_sub.text = "%s %d/%d%s" % [I18n.t("world_label"), b + 1, int(GameplayLits.c("TOTAL_BIOMES")), cycle_str]
	var key: String = "biome_%02d" % (b + 1)
	UiIcons.apply(%BiomeIcon as TextureRect, key, UiIcons.color_for(key), banner_name.text)


## Lista de efeitos ativos (activeEffects() + chips estaticos Escudo/Rebote). Retorna
## [{key, name, t, max, color}] com t < 0 para estaticos (texto em `text`).
func collect_effects(run: GameRun) -> Array:
	var list: Array = []
	if run.shield_charges > 0:
		list.append({"key": "shield", "name": I18n.t("fx_shield_name"), "static": true, "text": "×%d" % run.shield_charges, "color": Color("#9ad8ff")})
	if run.rebound_active:
		list.append({"key": "rebound", "name": I18n.t("fx_rebound_name"), "static": true, "text": I18n.t("fx_rebound_ready"), "color": Color("#ffd166")})
	if run.bear_boost_timer > 0.0:
		list.append({"key": "speed", "name": I18n.t("fx_speed"), "t": run.bear_boost_timer, "max": run.bear_boost_max, "color": Color("#7CFFB2")})
	if run.post_jump_timer > 0.0:
		list.append({"key": "postjump", "name": I18n.t("fx_postjump"), "t": run.post_jump_timer, "max": run.post_jump_max, "color": Color("#9ad8ff")})
	if run.ghost_slow_timer > 0.0:
		list.append({"key": "slow", "name": I18n.t("fx_slow"), "t": run.ghost_slow_timer, "max": run.ghost_slow_max, "color": Color("#8ab4ff")})
	if run.invisible_timer > 0.0:
		list.append({"key": "invisible", "name": I18n.t("fx_invisible"), "t": run.invisible_timer, "max": run.invisible_max, "color": Color("#c9b3ff")})
	if run.phase_timer > 0.0:
		list.append({"key": "phase", "name": I18n.t("fx_phase"), "t": run.phase_timer, "max": run.phase_max, "color": Color("#ffd166")})
	if run.decoy != null:
		var d: Dictionary = run.decoy as Dictionary
		list.append({"key": "decoy", "name": I18n.t("fx_decoy"), "t": float(d["life"]), "max": float(d["max_life"]), "color": Color("#ffb066")})
	var fmax: float = 0.0
	var tmax: float = 0.0
	for g in run.ghosts:
		fmax = maxf(fmax, g.frozen)
		tmax = maxf(tmax, g.trapped)
	if fmax > 0.0:
		list.append({"key": "frozen", "name": I18n.t("fx_frozen"), "t": fmax, "max": FROZEN_MAX, "color": Color("#9be0ff")})
	if tmax > 0.0:
		list.append({"key": "trapped", "name": I18n.t("fx_trapped"), "t": tmax, "max": TRAPPED_MAX, "color": Color("#d0d0e0")})
	return list


func _update_fx(run: GameRun) -> void:
	var wanted: Dictionary = {}
	for e: Dictionary in collect_effects(run):
		var k: String = str(e["key"])
		wanted[k] = true
		var chip: FxChip = _fx_chips.get(k) as FxChip
		if chip == null:
			chip = FX_CHIP.instantiate() as FxChip
			fx_list.add_child(chip)
			_fx_chips[k] = chip
		if bool(e.get("static", false)):
			chip.set_static(k, str(e["name"]), str(e["text"]), e["color"] as Color)
		else:
			chip.set_timed(k, str(e["name"]), float(e["t"]), float(e["max"]), e["color"] as Color)
	for k: String in _fx_chips.keys():
		if not wanted.has(k):
			(_fx_chips[k] as FxChip).queue_free()
			_fx_chips.erase(k)


## renderPassiveHud(): buffs fixos com cooldown restante.
func _update_passives(buffs: BuffSystem) -> void:
	if buffs == null:
		return
	var wanted: Dictionary = {}
	for id: String in buffs.fixed_buffs:
		wanted[id] = true
		var chip: PassiveChip = _passive_chips.get(id) as PassiveChip
		if chip == null:
			chip = PASSIVE_CHIP.instantiate() as PassiveChip
			passive_list.add_child(chip)
			_passive_chips[id] = chip
		chip.set_buff(id, maxi(0, ceili(float(buffs.fixed_timers.get(id, 0.0)))))
	for id: String in _passive_chips.keys():
		if not wanted.has(id):
			(_passive_chips[id] as PassiveChip).queue_free()
			_passive_chips.erase(id)


func clear_chips() -> void:
	for c: Node in fx_list.get_children():
		c.queue_free()
	for c: Node in passive_list.get_children():
		c.queue_free()
	_fx_chips.clear()
	_passive_chips.clear()
