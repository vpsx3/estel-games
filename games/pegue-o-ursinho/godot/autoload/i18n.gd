extends Node
## Idioma PT/EN. Web: le/grava localStorage['estel_lang'].

const WEB_KEY: String = "estel_lang"
const FILE_PATH: String = "user://lang.txt"

var lang: String = "pt"


func _ready() -> void:
	lang = _load_lang()


func set_lang(new_lang: String) -> void:
	if new_lang != "pt" and new_lang != "en":
		return
	lang = new_lang
	_store_lang()
	Events.language_changed.emit(lang)


## Texto de UI (STRINGS_GAME). Cai para PT e depois para a propria chave.
func t(key: String) -> String:
	var primary: Dictionary = _table(lang).get("game", {}) as Dictionary
	if primary.has(key):
		return str(primary[key])
	var fallback: Dictionary = GameState.strings_pt.get("game", {}) as Dictionary
	return str(fallback.get(key, key))


func buff_name(id: String) -> String:
	return str(_buff_entry(id).get("name", id))


func buff_desc(id: String) -> String:
	return str(_buff_entry(id).get("desc", ""))


func map_fx(id: String) -> String:
	var tbl: Dictionary = _table(lang).get("map_fx", {}) as Dictionary
	if tbl.has(id):
		return str(tbl[id])
	return str((GameState.strings_pt.get("map_fx", {}) as Dictionary).get(id, ""))


## idx = indice 0-based do bioma.
func biome_name(idx: int) -> String:
	var id: String = str(int((GameState.biomes[idx] as Dictionary)["id"]))
	var tbl: Dictionary = _table(lang).get("biome_names", {}) as Dictionary
	if tbl.has(id):
		return str(tbl[id])
	return str((GameState.strings_pt.get("biome_names", {}) as Dictionary).get(id, id))


func attr_name(id: String) -> String:
	var tbl: Dictionary = _table(lang).get("attrs", {}) as Dictionary
	if tbl.has(id):
		return str(tbl[id])
	return str((GameState.strings_pt.get("attrs", {}) as Dictionary).get(id, id))


func rarity_label(rar: String) -> String:
	return str((_table(lang).get("rarity", {}) as Dictionary).get(rar, rar))


func _buff_entry(id: String) -> Dictionary:
	var tbl: Dictionary = _table(lang).get("buffs", {}) as Dictionary
	if tbl.has(id):
		return tbl[id] as Dictionary
	return (GameState.strings_pt.get("buffs", {}) as Dictionary).get(id, {}) as Dictionary


func _table(l: String) -> Dictionary:
	return GameState.strings_en if l == "en" else GameState.strings_pt


func _load_lang() -> String:
	var v: String = ""
	if OS.has_feature("web"):
		var r: Variant = JavaScriptBridge.eval("window.localStorage.getItem(%s)" % JSON.stringify(WEB_KEY), true)
		v = str(r) if r != null else ""
	elif FileAccess.file_exists(FILE_PATH):
		v = FileAccess.get_file_as_string(FILE_PATH).strip_edges()
	return v if v == "en" or v == "pt" else "pt"


func _store_lang() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.localStorage.setItem(%s, %s)" % [JSON.stringify(WEB_KEY), JSON.stringify(lang)], true)
	else:
		var f: FileAccess = FileAccess.open(FILE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(lang)
