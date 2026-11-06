extends Node
## Idioma PT/EN (T / setLang / initLang do index.html). Web: localStorage['estel_lang'].
## Textos vem de data/legacy/strings_*.json (STRINGS_GAME etc.) + i18n/ui_extra.json (textos que o
## HTML nao tem: pausa...). Toda saida de texto passa por UiText.strip_emoji (UI sem emoji);
## t_raw devolve o dado original.

const WEB_KEY: String = "estel_lang"
const FILE_PATH: String = "user://lang.txt"
const EXTRA_PATH: String = "res://i18n/ui_extra.json"

var lang: String = "pt"
var file_path: String = FILE_PATH   # sobrescrevivel em testes
var _extra: Dictionary = {}


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EXTRA_PATH))
	_extra = parsed as Dictionary if parsed is Dictionary else {}
	lang = _load_lang()


## setLang(lang): grava a preferencia e avisa as telas (Events.language_changed).
func set_lang(new_lang: String) -> void:
	if new_lang != "pt" and new_lang != "en":
		return
	lang = new_lang
	_store_lang()
	Events.language_changed.emit(lang)


## T(key): texto de UI sem emoji. Cai para PT e depois para a propria chave.
func t(key: String) -> String:
	return UiText.strip_emoji(t_raw(key))


## T(key) com {n} etc. substituidos a partir de `params`.
func tf(key: String, params: Dictionary) -> String:
	var s: String = t_raw(key)
	for k: Variant in params:
		s = s.replace("{%s}" % str(k), str(params[k]))
	return UiText.strip_emoji(s)


## Texto cru (com emoji), como no STRINGS_GAME. Ordem: idioma -> extra do idioma -> PT -> extra PT -> chave.
func t_raw(key: String) -> String:
	var primary: Dictionary = _table(lang).get("game", {}) as Dictionary
	if primary.has(key):
		return str(primary[key])
	var ex: Dictionary = _extra.get(lang, {}) as Dictionary
	if ex.has(key):
		return str(ex[key])
	var fallback: Dictionary = GameState.strings_pt.get("game", {}) as Dictionary
	if fallback.has(key):
		return str(fallback[key])
	return str((_extra.get("pt", {}) as Dictionary).get(key, key))


## Chaves de UI conhecidas (STRINGS_GAME + extras), para varreduras.
func all_keys() -> Array:
	var keys: Array = (GameState.strings_pt.get("game", {}) as Dictionary).keys()
	for l: String in ["pt", "en"]:
		for k: Variant in (_extra.get(l, {}) as Dictionary):
			if not keys.has(k):
				keys.append(k)
	return keys


## buffName(id)
func buff_name(id: String) -> String:
	return UiText.strip_emoji(str(_buff_entry(id).get("name", id)))


## buffDesc(id)
func buff_desc(id: String) -> String:
	return UiText.strip_emoji(str(_buff_entry(id).get("desc", "")))


## mapFxText(id)
func map_fx(id: String) -> String:
	var tbl: Dictionary = _table(lang).get("map_fx", {}) as Dictionary
	if tbl.has(id):
		return UiText.strip_emoji(str(tbl[id]))
	return UiText.strip_emoji(str((GameState.strings_pt.get("map_fx", {}) as Dictionary).get(id, "")))


## biomeName(idx): idx = indice 0-based do bioma.
func biome_name(idx: int) -> String:
	var id: String = str(int((GameState.biomes[idx] as Dictionary)["id"]))
	var tbl: Dictionary = _table(lang).get("biome_names", {}) as Dictionary
	if tbl.has(id):
		return UiText.strip_emoji(str(tbl[id]))
	return UiText.strip_emoji(str((GameState.strings_pt.get("biome_names", {}) as Dictionary).get(id, id)))


## attrName(id)
func attr_name(id: String) -> String:
	var tbl: Dictionary = _table(lang).get("attrs", {}) as Dictionary
	if tbl.has(id):
		return UiText.strip_emoji(str(tbl[id]))
	return UiText.strip_emoji(str((GameState.strings_pt.get("attrs", {}) as Dictionary).get(id, id)))


## rarLabel(r)
func rarity_label(rar: String) -> String:
	return UiText.strip_emoji(str((_table(lang).get("rarity", {}) as Dictionary).get(rar, rar)))


func _buff_entry(id: String) -> Dictionary:
	var tbl: Dictionary = _table(lang).get("buffs", {}) as Dictionary
	if tbl.has(id):
		return tbl[id] as Dictionary
	return (GameState.strings_pt.get("buffs", {}) as Dictionary).get(id, {}) as Dictionary


func _table(l: String) -> Dictionary:
	return GameState.strings_en if l == "en" else GameState.strings_pt


## initLang(): salvo -> (web) idioma do navegador -> PT. localStorage['estel_lang'] / user://lang.txt.
func _load_lang() -> String:
	var v: String = ""
	if OS.has_feature("web"):
		v = WebBridge.ls_get(WEB_KEY)
		if v != "en" and v != "pt":
			return "pt" if WebBridge.nav_language().begins_with("pt") else "en"
	elif FileAccess.file_exists(file_path):
		v = FileAccess.get_file_as_string(file_path).strip_edges()
	return v if v == "en" or v == "pt" else "pt"


func _store_lang() -> void:
	if OS.has_feature("web"):
		WebBridge.ls_set(WEB_KEY, lang)
	else:
		var f: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
		if f != null:
			f.store_string(lang)
