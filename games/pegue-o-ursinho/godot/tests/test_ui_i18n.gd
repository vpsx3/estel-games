extends "res://tests/case.gd"
## I18n: PT/EN, fallback, troca em runtime, persistencia e ausencia de emoji nos textos.

const TMP: String = "user://_test_lang.txt"


func _restore(old_lang: String, old_path: String) -> void:
	I18n.file_path = old_path
	I18n.lang = old_lang
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func test_pt_en_and_fallback() -> void:
	var old: String = I18n.lang
	I18n.lang = "pt"
	eq(I18n.t("btnPlay"), "Jogar", "pt")
	eq(I18n.t("btn_start_run"), "Iniciar ({n}/3)", "pt template")
	eq(I18n.tf("btn_start_run", {"n": 2}), "Iniciar (2/3)", "tf")
	eq(I18n.t("chave_inexistente"), "chave_inexistente", "cai para a chave")
	eq(I18n.t("result_reached"), "Você chegou até: ", "espaco final preservado")
	I18n.lang = "en"
	eq(I18n.t("btnPlay"), "Play", "en")
	eq(I18n.biome_name(0), I18n.biome_name(0), "biome en")
	check(I18n.biome_name(0) != "Floresta Encantada", "bioma traduzido em EN")
	eq(I18n.buff_name("dash"), "Dash", "buff en")
	eq(I18n.t("pause_title"), "Paused", "extra en")
	I18n.lang = old


func test_every_key_has_both_languages() -> void:
	var pt: Dictionary = GameState.strings_pt["game"]
	var en: Dictionary = GameState.strings_en["game"]
	eq(pt.keys().size(), en.keys().size(), "mesmo numero de chaves")
	for k: Variant in pt:
		check(en.has(k), "EN tem " + str(k))


func test_no_emoji_anywhere() -> void:
	var old: String = I18n.lang
	for l: String in ["pt", "en"]:
		I18n.lang = l
		for k: Variant in I18n.all_keys():
			check(not UiText.has_emoji(I18n.t(str(k))), "sem emoji t(%s) %s" % [k, l])
		for i in GameState.biomes.size():
			check(not UiText.has_emoji(I18n.biome_name(i)), "bioma %d %s" % [i, l])
		for b: Dictionary in BuffSystem.all_buffs():
			var id: String = str(b["id"])
			check(not UiText.has_emoji(I18n.buff_name(id)), "buff nome " + id)
			check(not UiText.has_emoji(I18n.buff_desc(id)), "buff desc " + id)
			check(not UiText.has_emoji(I18n.map_fx(id)), "map_fx " + id)
		for id: String in Shop.order():
			check(not UiText.has_emoji(I18n.attr_name(id)), "attr " + id)
		for r: String in ["comum", "incomum", "raro"]:
			check(not UiText.has_emoji(I18n.rarity_label(r)), "raridade " + r)
	I18n.lang = old
	eq(UiText.strip_emoji("🏆 Ranking"), "Ranking", "strip")
	eq(UiText.strip_emoji("▶ Jogar"), "Jogar", "strip simbolo")
	eq(UiText.strip_emoji("Novo mapa em "), "Novo mapa em ", "sem emoji nao mexe")


func test_set_lang_signal_and_persistence() -> void:
	var old_lang: String = I18n.lang
	var old_path: String = I18n.file_path
	I18n.file_path = TMP
	var got: Array = []
	var cb: Callable = func(l: String) -> void: got.append(l)
	Events.language_changed.connect(cb)
	I18n.set_lang("en")
	I18n.set_lang("xx")   # ignorado
	Events.language_changed.disconnect(cb)
	eq(got, ["en"], "sinal so para idioma valido")
	eq(I18n._load_lang(), "en", "persistido")
	I18n.set_lang("pt")
	eq(I18n._load_lang(), "pt", "persistido pt")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	eq(I18n._load_lang(), "pt", "sem arquivo => PT")
	_restore(old_lang, old_path)


func test_format_time() -> void:
	eq(UiText.format_time(0), "0:00", "0")
	eq(UiText.format_time(65.9), "1:05", "65s")
	eq(UiText.format_time(600), "10:00", "600s")
