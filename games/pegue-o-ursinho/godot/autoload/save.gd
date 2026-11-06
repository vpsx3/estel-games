extends Node
## Persistencia: {honey, attrs{}, skins{owned,equipped}} (DEFAULT_SAVE / loadSave / persistSave).
## Web: localStorage['estel_pou_save'] via JavaScriptBridge. Fora do web: user://save.json.
## Compativel com o que o HTML grava; campos desconhecidos (topo, attrs, skins) sao preservados.

const WEB_KEY: String = "estel_pou_save"
const FILE_PATH: String = "user://save.json"

var data: Dictionary = {}
var file_path: String = FILE_PATH   # sobrescrevivel em testes


func _ready() -> void:
	load_save()


static func default_save() -> Dictionary:
	return {
		"honey": 0,
		"attrs": {"speed_base": 0, "jump_cd": 0, "jump_ext": 0, "double_jump": 0, "reroll": 0},
		"skins": {"owned": ["default"], "equipped": "default"},
	}


## loadSave() a partir do texto cru (JSON). Texto vazio/invalido => default.
static func parse_text(raw: String) -> Dictionary:
	var d: Dictionary = default_save()
	if raw.is_empty():
		return d
	var j: JSON = JSON.new()
	if j.parse(raw) != OK or not (j.data is Dictionary):
		return d   # try/catch do JS: save invalido => default
	var p: Dictionary = _norm(j.data) as Dictionary
	for k: String in p:
		if k != "honey" and k != "attrs" and k != "skins":
			d[k] = p[k]   # campo desconhecido: preservado
	d["honey"] = int(p.get("honey", 0))
	if p.get("attrs") is Dictionary:
		(d["attrs"] as Dictionary).merge(p["attrs"] as Dictionary, true)
	if p.get("skins") is Dictionary:
		(d["skins"] as Dictionary).merge(p["skins"] as Dictionary, true)
	return d


## persistSave(): JSON do save.
static func to_text(d: Dictionary) -> String:
	return JSON.stringify(d)


func load_save() -> Dictionary:
	data = parse_text(_read_raw())
	return data


func persist() -> void:
	_write_raw(to_text(data))


func honey() -> int:
	return int(data.get("honey", 0))


func add_honey(amount: int) -> void:
	data["honey"] = honey() + amount
	persist()


func attr_level(attr_id: String) -> int:
	return int((data["attrs"] as Dictionary).get(attr_id, 0))


# JSON entrega numeros como float: inteiros voltam a int (evita "1.0" no JSON gravado).
static func _norm(v: Variant) -> Variant:
	if v is Dictionary:
		var out: Dictionary = {}
		for k: Variant in (v as Dictionary):
			out[k] = _norm((v as Dictionary)[k])
		return out
	if v is Array:
		var arr: Array = []
		for e: Variant in (v as Array):
			arr.append(_norm(e))
		return arr
	if v is float and is_equal_approx(floorf(v), v) and absf(v) < 1.0e15:
		return int(v)
	return v


func _read_raw() -> String:
	if OS.has_feature("web"):
		return WebBridge.ls_get(WEB_KEY)
	if FileAccess.file_exists(file_path):
		return FileAccess.get_file_as_string(file_path)
	return ""


func _write_raw(text: String) -> void:
	if OS.has_feature("web"):
		WebBridge.ls_set(WEB_KEY, text)
		return
	var f: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
