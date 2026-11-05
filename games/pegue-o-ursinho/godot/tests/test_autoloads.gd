extends "res://tests/case.gd"
## Autoloads carregam os dados legados e expoem a API publica basica.

func _autoload(node_name: String) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(node_name)


func test_game_state_loaded() -> void:
	var gs: Node = _autoload("GameState")
	check(gs != null, "autoload GameState presente")
	if gs == null:
		return
	eq((gs.get("maps") as Array).size(), 10, "GameState.maps")
	eq((gs.get("biomes") as Array).size(), 10, "GameState.biomes")
	eq(int(gs.call("const_value", "BIOME_DURATION")), 120, "const_value BIOME_DURATION")
	check(bool(gs.call("is_wall", 0, 0, 0)), "borda e parede")
	check(bool(gs.call("is_wall", 0, -1, 5)), "fora do mapa e parede")
	check(not bool(gs.call("is_wall", 0, 8, 14)), "spawn do urso (bioma 1) e livre")


func test_i18n_and_save_defaults() -> void:
	var i18n: Node = _autoload("I18n")
	check(i18n != null, "autoload I18n presente")
	if i18n != null:
		eq(str(i18n.call("biome_name", 0)), "Floresta Encantada", "biome_name pt")
		eq(str(i18n.call("buff_name", "dash")), "Dash", "buff_name pt")
	var sv: Node = _autoload("Save")
	check(sv != null, "autoload Save presente")
	if sv != null:
		var d: Dictionary = sv.call("default_save") as Dictionary
		check(d.has("honey") and d.has("attrs") and d.has("skins"), "default_save com honey/attrs/skins")
	for n: String in ["Events", "ApiClient", "Audio"]:
		check(_autoload(n) != null, "autoload %s presente" % n)
	var api: Node = _autoload("ApiClient")
	if api != null:
		eq(str(api.get("GAME_ID")), "pegue-o-ursinho", "ApiClient.GAME_ID")
