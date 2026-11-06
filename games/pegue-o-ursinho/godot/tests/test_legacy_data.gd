extends "res://tests/case.gd"
## Dados legados extraidos + conversoes de unidade.

const UnitsS: GDScript = preload("res://scripts/core/units.gd")
const DIR: String = "res://data/legacy/"


func test_maps_shape_and_values() -> void:
	var maps: Array = read_json(DIR + "maps.json") as Array
	eq(maps.size(), 10, "10 mapas")
	for i in maps.size():
		var g: Array = maps[i]
		eq(g.size(), 30, "mapa %d: 30 linhas" % (i + 1))
		var bad: int = 0
		for r in g.size():
			var row: Array = g[r]
			if row.size() != 18:
				bad += 1
			for v: Variant in row:
				if int(v) != 0 and int(v) != 1:
					bad += 1
		eq(bad, 0, "mapa %d: 18 colunas e so 0/1" % (i + 1))


func test_expected_keys() -> void:
	var biomes: Array = read_json(DIR + "biomes.json") as Array
	eq(biomes.size(), 10, "10 biomas")
	for b: Dictionary in biomes:
		for k: String in ["id", "name", "icon", "wallTint", "bgColor", "ghostSpeed", "ghostSpawnRate", "bearSpawn", "ghostSpawn"]:
			check(b.has(k), "bioma %s sem chave %s" % [str(b.get("id")), k])
	var mech: Dictionary = read_json(DIR + "biome_mech.json") as Dictionary
	eq(mech.size(), 10, "10 biome_mech")
	for i in 10:
		check(mech.has(str(i)) and (mech[str(i)] as Dictionary).has("type"), "biome_mech %d com type" % i)
	var ghosts: Dictionary = read_json(DIR + "ghost_types.json") as Dictionary
	for gt: String in ["comum", "rapido", "pesado", "errante", "venenoso"]:
		check(ghosts.has(gt), "ghost_type " + gt)
		for k: String in ["speed", "size", "minDist", "weight"]:
			check((ghosts.get(gt, {}) as Dictionary).has(k), "ghost %s.%s" % [gt, k])
	var buffs: Dictionary = read_json(DIR + "buffs.json") as Dictionary
	eq((buffs["map_buffs"] as Array).size(), 16, "16 buffs")
	var attrs: Dictionary = read_json(DIR + "attrs.json") as Dictionary
	for a: String in ["speed_base", "jump_cd", "jump_ext", "double_jump", "reroll"]:
		check((attrs["defs"] as Dictionary).has(a), "attr " + a)
	var c: Dictionary = read_json(DIR + "constants.json") as Dictionary
	for k: String in ["TILE", "BIOME_DURATION", "TOTAL_BIOMES", "BIOME_WARNING_TIME", "HONEY_PASSIVE_RATE",
			"HONEY_PICKUP_VALUE", "HONEY_SPAWN_INTERVAL", "HONEY_MAX_ON_MAP", "HONEY_LIFE", "HONEY_R",
			"POISON_RADIUS", "POISON_DEBUFF", "POISON_DURATION", "POISON_COOLDOWN", "JUMP_DURATION",
			"INITIAL_PACE", "GHOST_PHASE_SCALING", "SPAWN_INTERVAL_BASE", "COLLECT_LIFE", "MAX_COLLECT",
			"COLLECT_R", "SPRAY_SLOW_MULT", "SPRAY_SLOW_DUR", "FIXED_INTERVALS", "CAM_CONFIG", "JOY_RADIUS",
			"BIOME_ANNOUNCE_DURATION", "SAVE_KEY", "GAME_ID", "MECH_SLOTS"]:
		check(c.has(k), "constants sem " + k)
	eq(c.get("TILE"), 36.0, "TILE legado = 36")
	eq(c.get("BIOME_DURATION"), 45.0, "BIOME_DURATION")
	eq(c.get("GAME_ID"), "pegue-o-ursinho", "GAME_ID")
	eq(c.get("SAVE_KEY"), "estel_pou_save", "SAVE_KEY")
	var pt: Dictionary = read_json(DIR + "strings_pt.json") as Dictionary
	var en: Dictionary = read_json(DIR + "strings_en.json") as Dictionary
	for tbl: Dictionary in [pt, en]:
		for k: String in ["game", "biome_names", "buffs", "map_fx", "attrs", "rarity"]:
			check(tbl.has(k), "strings sem " + k)
	eq((pt["game"] as Dictionary).size(), (en["game"] as Dictionary).size(), "STRINGS pt/en mesmo tamanho")


func test_units_conversions() -> void:
	near(UnitsS.TILE_SCALE, 32.0 / 36.0, "TILE_SCALE")
	near(UnitsS.speed_px_frame_to_px_s(1.7), 1.7 * 60.0 * 32.0 / 36.0, "velocidade comum")
	near(UnitsS.speed_px_frame_to_px_s(0.0), 0.0, "velocidade zero")
	near(UnitsS.px(36.0), 32.0, "36 px legados = 32 px")
	near(UnitsS.px(80.0), 80.0 * 32.0 / 36.0, "POISON_RADIUS")
	eq(UnitsS.WORLD_W, 576, "largura do mundo")
	eq(UnitsS.WORLD_H, 960, "altura do mundo")
	eq(UnitsS.cell_center(0, 0), Vector2(16, 16), "centro da celula 0,0")
	eq(UnitsS.world_to_cell(Vector2(575, 959)), Vector2i(17, 29), "ultima celula")
	var c: Dictionary = read_json(DIR + "constants.json") as Dictionary
	eq(int(c["ROWS"]), 30, "ROWS = 30")
	eq(int(c["COLS"]), 18, "COLS = 18")
	eq(int(c["TILE"]) * int(c["COLS"]), 648, "canvas legado 648 de largura")
