extends SceneTree
## Captura screenshots das telas de UI (precisa de janela, NAO headless):
##   "$GODOT_PATH" --path games/pegue-o-ursinho/godot --script res://tools/capture_ui.gd
## Saida: docs/arte/screens/ui_*.png. Usa save/idioma temporarios e ApiClient mockado.

const OUT: String = "res://docs/arte/screens/"


func _shot(name: String) -> void:
	print("shot start ", name)
	for i in 8:
		await process_frame
	RenderingServer.force_draw()
	var img: Image = root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	img.save_png(ProjectSettings.globalize_path(OUT + "ui_%s.png" % name))
	print("shot ", name, " ", img.get_size())


func _initialize() -> void:
	await process_frame
	var save: Node = root.get_node("Save")
	var i18n: Node = root.get_node("I18n")
	var api: Node = root.get_node("ApiClient")
	save.file_path = "user://_capture_save.json"
	i18n.file_path = "user://_capture_lang.txt"
	save.data = save.default_save()
	save.data["honey"] = 1234
	i18n.lang = "pt"
	var scores: Array = []
	for i in 10:
		scores.append({"nick": "Ursinho%d" % (i + 1), "seconds": 300 - i * 23, "ghosts": 12 - i})
	scores[3]["nick"] = "Tester"
	api.transport = func(method: String, url: String, _body: Variant) -> Dictionary:
		if url.ends_with("/api/session"):
			return {"ok": true, "data": {"token": "tk"}}
		if method == "GET":
			return {"ok": true, "data": scores}
		return {"ok": true, "data": {"rank": 4, "scores": scores}}
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _shot("00_nick")
	main.nick_screen.nick_input.text = "Tester"
	main.nick_screen.submit()
	await _shot("01_inicio")
	main.open_upgrades()
	await _shot("02_loja")
	main.show_menu()
	main.open_ranking("menu", "Tester", 231)
	await create_timer(0.5).timeout
	await _shot("03_ranking")
	main.show_menu()
	main.start_game()
	await create_timer(0.3).timeout
	await _shot("04_selecao_buffs")
	var sel: Node = main.buff_select_screen
	for i in 3:
		(sel.card_nodes[i] as Button).pressed.emit()
	await _shot("04b_selecao_3")
	sel.start_button.pressed.emit()
	await process_frame
	if main.state != "playing":
		main.start_run()
	for t: Node in main.game.find_children("Touch", "Control", true, false):
		(t as Control).visible = true
	for i in 90:
		await process_frame
	await _shot("05_hud_jogo")
	DisplayServer.window_set_size(Vector2i(390, 844))
	for i in 20:
		await process_frame
	await _shot("07_hud_390x844")
	DisplayServer.window_set_size(Vector2i(576, 1024))
	for i in 10:
		await process_frame
	main.toggle_pause()
	await _shot("06_pausa")
	main.resume()
	quit(0)
