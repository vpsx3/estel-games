class_name MainFlow
extends Node
## Fluxo completo do jogo (screens do HTML): nick -> menu -> (upgrades | ranking) ->
## selecao 3 de 5 -> run (HUD, pausa, escolha de +1 buff entre biomes) -> game over -> ranking.
## Possui a instancia de Game (scenes/game.tscn) durante a run. So orquestra: regras no gameplay.

const GAME_SCENE: PackedScene = preload("res://scenes/game.tscn")

@onready var game_holder: Node = %GameHolder
@onready var nick_screen: NickScreen = %NickScreen
@onready var menu_screen: MenuScreen = %MenuScreen
@onready var upgrades_screen: UpgradesScreen = %UpgradesScreen
@onready var ranking_screen: RankingScreen = %RankingScreen
@onready var buff_select_screen: BuffSelectScreen = %BuffSelectScreen
@onready var world_choice_screen: WorldChoiceScreen = %WorldChoiceScreen
@onready var result_screen: ResultScreen = %ResultScreen
@onready var pause_screen: PauseScreen = %PauseScreen
@onready var hud: Hud = %Hud

var state: String = "nick"   # nick | menu | upgrades | ranking | selection | playing | choosing | paused | result
var player_nick: String = ""
var game: Node2D = null
var last_saved: Dictionary = {}   # lastSavedRankData {nick, secs}
var _ranking_back: String = "menu"


func _ready() -> void:
	nick_screen.submitted.connect(_on_nick)
	nick_screen.ranking_requested.connect(func() -> void: open_ranking("nick"))
	menu_screen.play_pressed.connect(start_game)
	menu_screen.upgrades_pressed.connect(open_upgrades)
	menu_screen.ranking_pressed.connect(func() -> void: open_ranking("menu"))
	upgrades_screen.back_pressed.connect(show_menu)
	ranking_screen.back_pressed.connect(_on_ranking_back)
	buff_select_screen.start_pressed.connect(start_run)
	world_choice_screen.picked.connect(_on_world_picked)
	world_choice_screen.reroll_requested.connect(_on_world_reroll)
	result_screen.play_again_pressed.connect(start_game)
	result_screen.menu_pressed.connect(show_menu)
	result_screen.ranking_pressed.connect(_on_result_ranking)
	pause_screen.resume_pressed.connect(resume)
	pause_screen.menu_pressed.connect(quit_to_menu)
	hud.pause_pressed.connect(toggle_pause)
	_show("nick")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and (state == "playing" or state == "paused"):
		toggle_pause()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- telas
func _screen_for(s: String) -> Control:
	match s:
		"nick": return nick_screen
		"menu": return menu_screen
		"upgrades": return upgrades_screen
		"ranking": return ranking_screen
		"selection": return buff_select_screen
		"result": return result_screen
	return null


## showScreen(id): so a tela pedida (e a HUD/overlays nos estados de jogo).
func _show(s: String) -> void:
	state = s
	for c: Control in [nick_screen, menu_screen, upgrades_screen, ranking_screen, buff_select_screen,
			world_choice_screen, result_screen, pause_screen, hud]:
		c.visible = false
	var scr: Control = _screen_for(s)
	if scr != null:
		scr.visible = true
	elif s == "playing":
		hud.visible = true
	elif s == "choosing":
		hud.visible = true
		world_choice_screen.visible = true
	elif s == "paused":
		hud.visible = true
		pause_screen.visible = true
	if s == "menu":
		menu_screen.refresh()


func _on_nick(nick: String) -> void:
	player_nick = nick
	show_menu()


func show_menu() -> void:
	_free_game()
	_show("menu")


func open_upgrades() -> void:
	upgrades_screen.refresh()
	_show("upgrades")


func open_ranking(back_to: String, hl_nick: String = "", hl_sec: int = -1) -> void:
	_ranking_back = back_to
	_show("ranking")
	ranking_screen.open(hl_nick, hl_sec)


func _on_ranking_back() -> void:
	if _ranking_back == "menu":
		show_menu()
	else:
		_show("nick")


func _on_result_ranking() -> void:
	open_ranking("menu", str(last_saved.get("nick", "")), int(last_saved.get("secs", -1)))


# ---------------------------------------------------------------- run
## startGame() -> openSelection()
func start_game() -> void:
	_free_game()
	game = GAME_SCENE.instantiate() as Node2D
	game.set("auto_start", false)
	game.set("show_debug", false)
	game.set("use_api", true)
	game_holder.add_child(game)
	game.call("prepare")
	var buffs: BuffSystem = game.get("buffs") as BuffSystem
	buffs.world_choice_opened.connect(_on_world_opened)
	buffs.world_choice_closed.connect(_on_world_closed)
	game.connect("run_ended", _on_run_ended)
	buff_select_screen.open(buffs)
	_show("selection")


## startRun()
func start_run() -> void:
	if game == null or not bool(game.call("begin")):
		return
	hud.bind(game)
	_show("playing")


func _on_world_opened(options: Array) -> void:
	var buffs: BuffSystem = game.get("buffs") as BuffSystem
	world_choice_screen.show_options(options, buffs.reroll_enabled(), buffs.reroll_used)
	if state != "choosing":
		_show("choosing")


func _on_world_closed() -> void:
	if state == "choosing":
		_show("playing")


func _on_world_picked(id: String) -> void:
	(game.get("buffs") as BuffSystem).pick_world_buff(id)


func _on_world_reroll() -> void:
	(game.get("buffs") as BuffSystem).world_reroll()


func toggle_pause() -> void:
	if state == "playing":
		game.call("set_paused", true)
		_show("paused")
	elif state == "paused":
		resume()


func resume() -> void:
	if state != "paused":
		return
	game.call("set_paused", false)
	_show("playing")


func quit_to_menu() -> void:
	show_menu()


## endGame(): tela de resultado + envio do score (nick digitado no inicio).
func _on_run_ended(stats: Dictionary) -> void:
	var buffs: BuffSystem = game.get("buffs") as BuffSystem
	result_screen.show_result(stats, buffs.build_ids)
	_show("result")
	var nick: String = player_nick
	var secs: int = int(stats["seconds"])
	var data: Dictionary = await ApiClient.save_score(nick, secs, int(stats["ghosts"]), str(stats["biome_reached"]))
	last_saved = {"nick": nick, "secs": secs}
	if is_inside_tree():
		result_screen.set_rank(data.get("rank"))


func _free_game() -> void:
	if game != null and is_instance_valid(game):
		game.call("set_paused", false)
		game_holder.remove_child(game)
		game.queue_free()
	game = null
	hud.bind(null)
