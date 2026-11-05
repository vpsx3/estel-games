extends Node
## Persistencia: {honey, attrs{}, skins{owned,equipped}}.
## Web: localStorage['estel_pou_save'] via JavaScriptBridge. Fora do web: user://save.json.

const WEB_KEY: String = "estel_pou_save"
const FILE_PATH: String = "user://save.json"

var data: Dictionary = {}


func _ready() -> void:
	load_save()


static func default_save() -> Dictionary:
	return {
		"honey": 0,
		"attrs": {"speed_base": 0, "jump_cd": 0, "jump_ext": 0, "double_jump": 0, "reroll": 0},
		"skins": {"owned": ["default"], "equipped": "default"},
	}


func load_save() -> Dictionary:
	var d: Dictionary = default_save()
	var raw: String = _read_raw()
	if not raw.is_empty():
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Dictionary:
			var p: Dictionary = parsed
			d["honey"] = int(p.get("honey", 0))
			(d["attrs"] as Dictionary).merge(p.get("attrs", {}) as Dictionary, true)
			(d["skins"] as Dictionary).merge(p.get("skins", {}) as Dictionary, true)
	data = d
	return data


func persist() -> void:
	_write_raw(JSON.stringify(data))


func honey() -> int:
	return int(data.get("honey", 0))


func add_honey(amount: int) -> void:
	data["honey"] = honey() + amount
	persist()


func attr_level(attr_id: String) -> int:
	return int((data["attrs"] as Dictionary).get(attr_id, 0))


func _read_raw() -> String:
	if OS.has_feature("web"):
		var v: Variant = JavaScriptBridge.eval("window.localStorage.getItem(%s)" % JSON.stringify(WEB_KEY), true)
		return str(v) if v != null else ""
	if FileAccess.file_exists(FILE_PATH):
		return FileAccess.get_file_as_string(FILE_PATH)
	return ""


func _write_raw(text: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.localStorage.setItem(%s, %s)" % [JSON.stringify(WEB_KEY), JSON.stringify(text)], true)
		return
	var f: FileAccess = FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
