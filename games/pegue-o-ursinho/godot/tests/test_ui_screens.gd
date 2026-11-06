extends "res://tests/case.gd"
## Telas e fluxo completo: inicio -> selecao -> jogo -> pausa -> escolha de mundo -> game over -> ranking,
## com ApiClient mockado. Troca de idioma e ausencia de emoji em todos os textos.

const TMP: String = "user://_test_flow_save.json"
const SCREENS: Array[String] = [
	"nick_screen", "menu_screen", "upgrades_screen", "ranking_screen", "buff_select_screen",
	"world_choice_screen", "result_screen", "pause_screen", "hud",
	"lang_toggle", "fx_chip", "passive_chip", "upgrade_card", "ranking_row", "buff_card"]


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _no_emoji_in(node: Node, what: String) -> void:
	for t: Variant in UiScreen.collect_texts(node):
		check(not UiText.has_emoji(str(t)), "emoji em '%s' (%s)" % [str(t), what])


func test_each_scene_instantiates_without_emoji() -> void:
	for n: String in SCREENS:
		var ps: PackedScene = load("res://scenes/ui/%s.tscn" % n) as PackedScene
		check(ps != null, "carrega " + n)
		if ps == null:
			continue
		var inst: Node = ps.instantiate()
		_tree().root.add_child(inst)
		_no_emoji_in(inst, n)
		inst.queue_free()
	check(load("res://scenes/main.tscn") != null, "main.tscn")
	eq(str(ProjectSettings.get_setting("application/run/main_scene")), "res://scenes/main.tscn", "main_scene")
	check(ProjectSettings.get_setting("gui/theme/custom") == "res://themes/cozy_theme.tres", "tema cozy")
	check(load("res://themes/cozy_theme.tres") is Theme, "tema carrega")


func test_buttons_min_height_and_viewport() -> void:
	eq(int(ProjectSettings.get_setting("display/window/size/viewport_width")), 576, "576")
	eq(int(ProjectSettings.get_setting("display/window/size/viewport_height")), 1024, "1024")
	for n: String in ["nick_screen", "menu_screen", "upgrades_screen", "ranking_screen", "buff_select_screen",
			"world_choice_screen", "result_screen", "pause_screen", "hud", "lang_toggle"]:
		var inst: Node = (load("res://scenes/ui/%s.tscn" % n) as PackedScene).instantiate()
		for b: Node in inst.find_children("*", "Button", true, false):
			check((b as Button).custom_minimum_size.y >= 48.0, "botao >= 48px: %s/%s" % [n, b.name])
		inst.free()


func test_nick_validation() -> void:
	eq(NickScreen.clean_nick("  ab  "), "ab", "trim")
	var s: NickScreen = (load("res://scenes/ui/nick_screen.tscn") as PackedScene).instantiate() as NickScreen
	_tree().root.add_child(s)
	eq(s.nick_input.max_length, 16, "maxlength 16")
	var got: Array = []
	s.submitted.connect(func(n: String) -> void: got.append(n))
	s.nick_input.text = "   "
	check(not s.submit(), "vazio recusado")
	eq(s.nick_input.theme_type_variation, &"InvalidLineEdit", "marca de erro")
	s.nick_input.text = " Ana "
	check(s.submit(), "valido")
	eq(got, ["Ana"], "nick aparado")
	eq(s.nick_input.theme_type_variation, &"", "erro limpo")
	s.queue_free()


func test_full_flow() -> void:
	var old_path: String = Save.file_path
	var old_data: Dictionary = Save.data
	var old_lang: String = I18n.lang
	var old_lpath: String = I18n.file_path
	Save.file_path = TMP
	I18n.file_path = "user://_test_flow_lang.txt"
	Save.data = Save.default_save()
	Save.data["honey"] = 1000
	I18n.lang = "pt"
	var log: Array = []
	ApiClient.transport = func(method: String, url: String, body: Variant) -> Dictionary:
		log.append({"method": method, "url": url, "body": body})
		if url.ends_with("/api/session"):
			return {"ok": true, "data": {"token": "tk"}}
		if method == "GET":
			return {"ok": true, "data": [{"nick": "Tester", "seconds": 0, "ghosts": 1}, {"nick": "Zed", "seconds": 50, "ghosts": 3}]}
		return {"ok": true, "data": {"rank": 1, "scores": []}}

	var main: MainFlow = (load("res://scenes/main.tscn") as PackedScene).instantiate() as MainFlow
	_tree().root.add_child(main)
	eq(main.state, "nick", "comeca no nick")
	check(main.nick_screen.visible and not main.menu_screen.visible, "so a tela de nick")
	# nick
	main.nick_screen.nick_input.text = ""
	main.nick_screen.submit()
	eq(main.state, "nick", "nick vazio nao avanca")
	main.nick_screen.nick_input.text = " Tester "
	main.nick_screen.submit()
	eq(main.state, "menu", "menu")
	eq(main.player_nick, "Tester", "nick guardado")
	eq(main.menu_screen.honey_label.text, "1000", "mel no menu")
	check(main.menu_screen.skins_button.disabled, "skins em breve")
	# loja
	main.menu_screen.upgrades_button.pressed.emit()
	eq(main.state, "upgrades", "loja")
	eq(main.upgrades_screen.list.get_child_count(), 5, "5 atributos")
	(main.upgrades_screen.list.get_child(0) as UpgradeCard).buy_button.pressed.emit()
	eq(Save.honey(), 950, "compra debita 50")
	eq(Save.attr_level("speed_base"), 1, "nivel 1")
	eq(main.upgrades_screen.balance_label.text, "950", "saldo atualizado")
	main.upgrades_screen.back_button.pressed.emit()
	eq(main.state, "menu", "volta ao menu")
	# selecao
	main.menu_screen.play_button.pressed.emit()
	eq(main.state, "selection", "selecao")
	eq(main.buff_select_screen.card_nodes.size(), 5, "5 opcoes")
	check(main.buff_select_screen.start_button.disabled, "iniciar desabilitado com 0/3")
	for i in 3:
		main.buff_select_screen.card_nodes[i].pressed.emit()
	eq(main.buff_select_screen.start_button.text, "Iniciar (3/3)", "texto 3/3")
	check(not main.buff_select_screen.start_button.disabled, "iniciar habilitado")
	main.buff_select_screen.card_nodes[3].pressed.emit()
	eq(main.game.get("buffs").selection_picks.size(), 3, "maximo 3")
	check(log.is_empty(), "sessao so ao iniciar a run")
	main.buff_select_screen.start_button.pressed.emit()
	eq(main.state, "playing", "jogando")
	check(main.hud.visible and not main.menu_screen.visible, "HUD visivel")
	eq(log[0]["url"].substr(log[0]["url"].length() - 12), "/api/session", "POST /api/session ao iniciar")
	var game: Node2D = main.game
	var run: GameRun = game.get("run") as GameRun
	eq(run.state, "playing", "run ativa")
	eq(int(run.attr_levels["speed_base"]), 1, "atributo comprado entra na run")
	check(not (game.get("touch") as Control).visible or Device.is_touch(), "touch so em dispositivos touch")
	for i in 5:
		game.call("_process", 0.016)
	main.hud._process(0.0)
	check(main.hud.timer_label.text.begins_with("0:0"), "timer")
	eq(main.hud.ghost_count_label.text, "×%d" % run.ghosts.size(), "contador de fantasmas")
	# efeito ativo aparece com barra
	run.bear_boost_timer = 2.0
	run.bear_boost_max = 4.0
	run.shield_charges = 1
	main.hud.update_from(run, game.get("buffs"))
	check(main.hud._fx_chips.has("speed") and main.hud._fx_chips.has("shield"), "chips de efeito")
	near(((main.hud._fx_chips["speed"] as FxChip).bar.value), 50.0, "barra 50%")
	run.bear_boost_timer = 0.0
	run.shield_charges = 0
	main.hud.update_from(run, game.get("buffs"))
	await _tree().process_frame
	check(not main.hud._fx_chips.has("speed"), "chip removido")
	# pausa
	var el: float = run.elapsed
	main.toggle_pause()
	eq(main.state, "paused", "pausado")
	check(main.pause_screen.visible, "tela de pausa")
	game.call("_process", 0.016)
	eq(run.elapsed, el, "tempo congelado na pausa")
	main.pause_screen.resume_button.pressed.emit()
	eq(main.state, "playing", "retomou")
	# aviso de fim de bioma
	run.cycle.phase = "warning"
	main.hud.update_from(run, game.get("buffs"))
	check(main.hud.warning_label.visible, "aviso de mudanca de mundo")
	run.cycle.phase = "playing"
	# escolha de +1 buff
	run.bear.invuln = 100.0
	run.execute_biome_transition()
	eq(main.state, "choosing", "escolha de mundo")
	eq(main.world_choice_screen.cards.get_child_count(), 3, "3 cartas")
	check(not main.world_choice_screen.reroll_button.visible, "reroll oculto sem atributo")
	var builds: int = (game.get("buffs") as BuffSystem).build_ids.size()
	((main.world_choice_screen.cards.get_child(0)) as BuffCard).pressed.emit()
	eq(main.state, "playing", "voltou ao jogo")
	eq((game.get("buffs") as BuffSystem).build_ids.size(), builds + 1, "buff adicionado")
	# reroll com atributo
	run.attr_levels["reroll"] = 1
	run.execute_biome_transition()
	check(main.world_choice_screen.reroll_button.visible and not main.world_choice_screen.reroll_button.disabled, "reroll disponivel")
	main.world_choice_screen.reroll_button.pressed.emit()
	check(main.world_choice_screen.reroll_button.disabled, "1 reroll por escolha")
	eq(main.world_choice_screen.cards.get_child_count(), 3, "novas 3 cartas")
	((main.world_choice_screen.cards.get_child(1)) as BuffCard).pressed.emit()
	eq(main.state, "playing", "escolheu")
	# game over
	run.end_game()
	await _tree().process_frame
	eq(main.state, "result", "resultado")
	var saved_call: Dictionary = log[log.size() - 1]
	eq(saved_call["method"], "POST", "POST score")
	eq(saved_call["body"]["nick"], "Tester", "nick enviado")
	eq(saved_call["body"]["token"], "tk", "token enviado")
	eq(saved_call["body"]["biomeReached"], str((GameState.biomes[run.cycle.current_biome] as Dictionary)["name"]), "bioma em PT")
	eq(main.result_screen.rank_msg_label.text, I18n.t("result_rank1"), "1o lugar")
	check(Save.honey() >= 950, "mel da run somado ao save")
	_no_emoji_in(main, "fluxo pt")
	# ranking destacando a partida
	main.result_screen.ranking_button.pressed.emit()
	eq(main.state, "ranking", "ranking")
	await _tree().process_frame
	eq(main.ranking_screen.rows.get_child_count(), 2, "2 linhas")
	var r0: RankingRow = main.ranking_screen.rows.get_child(0) as RankingRow
	eq(r0.rank_label.text, "1º", "1o")
	check(r0.new_badge.visible == (int(main.last_saved["secs"]) == 0), "destaque da partida")
	check(not (main.ranking_screen.rows.get_child(1) as RankingRow).new_badge.visible, "outro sem destaque")
	# idioma em runtime
	main.ranking_screen.back_pressed.emit()
	eq(main.state, "menu", "menu")
	eq(main.menu_screen.play_button.text, "Jogar", "pt")
	I18n.set_lang("en")
	eq(main.menu_screen.play_button.text, "Play", "en em runtime")
	eq(main.menu_screen.upgrades_button.text, "Upgrades", "upgrades en")
	_no_emoji_in(main, "fluxo en")
	I18n.set_lang("pt")
	eq(main.menu_screen.play_button.text, "Jogar", "volta pt")
	# jogar de novo e sair pela pausa
	main.menu_screen.play_button.pressed.emit()
	for i in 3:
		main.buff_select_screen.card_nodes[i].pressed.emit()
	main.buff_select_screen.start_button.pressed.emit()
	main.toggle_pause()
	main.pause_screen.menu_button.pressed.emit()
	eq(main.state, "menu", "sair para o menu")
	check(main.game == null, "run abandonada liberada")

	main.queue_free()
	await _tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(I18n.file_path))
	ApiClient.transport = Callable()
	ApiClient.session_token = ""
	Save.file_path = old_path
	Save.data = old_data
	I18n.lang = old_lang
	I18n.file_path = old_lpath
