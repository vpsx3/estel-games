extends Node2D
## Cena de jogo (E4a): liga GameRun (simulacao) a nos (level, urso, fantasmas, camera, controles).
## Fase: LevelIndex.scene_path(i) se existir (contrato do level-designer), senao o duplo de
## tests/support/fake_level.gd.
## Fluxo com telas (E4c): scripts/ui/main_flow.gd instancia esta cena com auto_start = false, chama
## prepare() (cria a run + sorteia as 5 opcoes), a UI de selecao escolhe 3 e begin() inicia
## (startRun). Com auto_start = true (testes/standalone) faz tudo sozinho: auto_pick + auto_choice.

const BEAR_SCENE: PackedScene = preload("res://scenes/actors/bear.tscn")
const GHOST_SCENE: PackedScene = preload("res://scenes/actors/ghost.tscn")
const FAKE_LEVEL_SCRIPT: String = "res://tests/support/fake_level.gd"

signal run_ended(stats: Dictionary)   # depois de somar o mel ao save (saveData.honey += runHoney)

@export var rng_seed: int = -1   # >= 0 => simulacao deterministica
@export var auto_start: bool = true    # false => a UI chama prepare() / begin()
@export var show_debug: bool = true    # Label de debug do E4a (a HUD real a substitui)
@export var use_api: bool = false      # true => begin() pede o token de sessao do ranking (startSession)

var paused: bool = false

var run: GameRun
var buffs: BuffSystem
var level: Node2D
var _bear_view: BearView
var _vfx: VfxDirector
var _under_view: WorldView
var _over_view: WorldView
var _ghost_views: Dictionary = {}   # GhostModel -> GhostView

@onready var world: Node2D = $World
@onready var camera: CameraRig = $Camera
@onready var debug_label: Label = $HUD/Debug
@onready var touch: TouchControls = $HUD/Touch


func _ready() -> void:
	touch.jump_pressed.connect(_on_jump)
	_under_view = WorldView.new()   # mecanica/orbes/mel/isca abaixo dos atores
	_under_view.mode = "under"
	world.add_child(_under_view)
	_over_view = WorldView.new()    # mecanica/notificacoes acima dos atores
	_over_view.mode = "over"
	_over_view.z_index = 10
	world.add_child(_over_view)
	debug_label.visible = show_debug
	if auto_start:
		new_run()


## Fluxo automatico (sem UI): 3 primeiras opcoes + escolha de mundo automatica.
func new_run() -> void:
	prepare()
	buffs.auto_choice = true
	buffs.auto_pick()
	begin()


## initGame ate openSelection: cria a run, carrega a fase 1 e sorteia as 5 opcoes pre-run.
func prepare() -> void:
	GameState.reset_run()
	paused = false
	_under_view.bind(null)
	_over_view.bind(null)
	for v: GhostView in _ghost_views.values():
		v.queue_free()
	_ghost_views.clear()
	if _bear_view != null:
		_bear_view.queue_free()
		_bear_view = null
	if _vfx != null:
		_vfx.queue_free()
		_vfx = null
	run = GameRun.new(rng_seed)
	run.sync_game_state = true
	run.attr_levels = Shop.new().levels()
	MechFactory.install(run)
	buffs = BuffSystem.new(run)
	buffs.attach()
	buffs.auto_choice = false  # a UI de escolha de mundo responde (pick_world_buff / world_reroll)
	run.level_loader = _load_level
	run.game_ended.connect(_on_game_ended)
	level = _load_level(0)
	buffs.open_selection()     # selecao pre-run 5 -> 3


## startRun(): exige 3 picks. Inicia a simulacao, cria as views e pede a sessao do ranking.
func begin() -> bool:
	if not buffs.start_run(level):
		return false
	_under_view.bind(run)
	_over_view.bind(run)
	_bear_view = BEAR_SCENE.instantiate() as BearView
	world.add_child(_bear_view)
	_bear_view.bind(run)
	_vfx = VfxDirector.new()   # VFX ligados a Events/estado da run (scripts/vfx)
	_vfx.bind(run, world)
	world.add_child(_vfx)
	camera.snap_to(run.bear.pos)
	if use_api:
		ApiClient.start_session()   # sem await: o token chega depois (falha silenciosa)
	return true


func set_paused(p: bool) -> void:
	if paused == p:
		return
	paused = p
	GameState.paused = p
	Events.pause_changed.emit(p)


func _process(delta: float) -> void:
	if run == null:
		return
	if run.state == "playing" and not paused:
		run.step(delta, InputReader.move_vector(touch.joystick))
		camera.follow(run.bear.pos, delta)
	_sync_ghost_views()
	if show_debug:
		_update_debug()


func _unhandled_input(event: InputEvent) -> void:
	if run == null:
		return
	if event.is_action_pressed("jump"):
		_on_jump()
	elif auto_start and run.state == "lose" and (event.is_action_pressed("ui_accept") or event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		new_run()


func _on_jump() -> void:
	if run == null:
		return
	if run.state == "lose":
		if auto_start:
			new_run()
	elif run.state == "playing" and not paused and run.cycle.phase != "choosing":
		run.try_jump()


func _on_game_ended(stats: Dictionary) -> void:
	Save.add_honey(int(stats["honey"]))   # saveData.honey += runHoney
	run_ended.emit(stats)


func _sync_ghost_views() -> void:
	var alive: Dictionary = {}
	for g in run.ghosts:
		alive[g] = true
		if not _ghost_views.has(g):
			var v: GhostView = GHOST_SCENE.instantiate() as GhostView
			world.add_child(v)
			v.bind(g)
			_ghost_views[g] = v
	for g: GhostModel in _ghost_views.keys():
		if not alive.has(g):
			(_ghost_views[g] as GhostView).queue_free()
			_ghost_views.erase(g)
	var visible_now: bool = run.cycle.ghost_hide_timer <= 0.0
	var alpha: float = run.ghost_alpha()
	for v: GhostView in _ghost_views.values():
		v.visible = visible_now
		v.self_modulate.a = alpha


func _update_debug() -> void:
	var t: int = floori(run.elapsed)
	var txt: String = "%d:%02d  ghosts x%d  honey %d  biome %d/%d (cycle %d)" % [
		t / 60, t % 60, run.ghosts.size(), run.run_honey, run.cycle.current_biome + 1,
		int(GameplayLits.c("TOTAL_BIOMES")), run.cycle.cycle_count + 1]
	if run.cycle.phase == "warning":
		txt += "\nmudando de mundo em %d..." % ceili(run.cycle.remaining(run.elapsed))
	if run.state == "lose":
		txt += "\nFIM  %ds  - toque/Enter para reiniciar" % int(run.last_stats.get("seconds", 0))
	debug_label.text = txt


# ---------------------------------------------------------------- fases
## Carrega a fase do bioma i. Troca a fase anterior (execucao da transicao).
func _load_level(i: int) -> Node2D:
	if level != null and is_instance_valid(level):
		world.remove_child(level)
		level.queue_free()
	var node: Node2D = _instantiate_level(i)
	world.add_child(node)
	world.move_child(node, 0)
	level = node
	return node


func _instantiate_level(i: int) -> Node2D:
	var path: String = _level_scene_path(i)
	if path != "" and ResourceLoader.exists(path):
		var ps: PackedScene = load(path) as PackedScene
		if ps != null:
			return ps.instantiate() as Node2D
	var fake: Node2D = Node2D.new()
	fake.set_script(load(FAKE_LEVEL_SCRIPT))
	fake.call("setup", i)
	return fake


## LevelIndex.scene_path(i) via cache de class_name (sem referencia estatica).
func _level_scene_path(i: int) -> String:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry["class"]) == "LevelIndex":
			var script: GDScript = load(str(entry["path"])) as GDScript
			if script != null:
				return str(script.call("scene_path", i))
	return ""
