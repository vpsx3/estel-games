class_name Shop
extends RefCounted
## Loja de atributos (sem UI). Porta ATTR_DEFS / ATTR_ORDER, attrLevel, attrNextCost,
## attrEffectText, buyAttr. Dados: GameState.attrs (data/legacy/attrs.json). Persistencia:
## Save (honey + attrs; estel_pou_save / user://save.json). Os efeitos em jogo vivem em
## GameRun.recalc_passives (velocidade) e JumpState.recalc (pulo cd/ext/duplo); reroll em BuffSystem.
##
## `store` / `persist` sao injetaveis para testes isolados (padrao = Save.data / Save.persist).

var _store: Dictionary = {}
var _use_save: bool = true
var _persist: Callable = Callable()


func _init(p_store: Variant = null, p_persist: Callable = Callable()) -> void:
	if p_store is Dictionary:
		_store = p_store as Dictionary
		_use_save = false
	_persist = p_persist


func _data() -> Dictionary:
	return Save.data if _use_save else _store


static func order() -> Array:
	return GameState.attrs["order"] as Array


static func def(id: String) -> Dictionary:
	return (GameState.attrs["defs"] as Dictionary)[id] as Dictionary


func honey() -> int:
	return int(_data().get("honey", 0))


## attrLevel(id)
func level(id: String) -> int:
	return int((_data().get("attrs", {}) as Dictionary).get(id, 0))


func max_level(id: String) -> int:
	return int(def(id)["maxLevel"])


func is_maxed(id: String) -> bool:
	return level(id) >= max_level(id)


## attrNextCost(id): -1 se ja esta no maximo.
func next_cost(id: String) -> int:
	var lv: int = level(id)
	if lv >= max_level(id):
		return -1
	return int((def(id)["costs"] as Array)[lv])


func can_buy(id: String) -> bool:
	var cost: int = next_cost(id)
	return cost >= 0 and honey() >= cost


## Valor do PROXIMO nivel (attrEffectText usa values[lv]); null se toggle/maximo.
func next_value(id: String) -> Variant:
	var d: Dictionary = def(id)
	if bool(d.get("toggle", false)):
		return null
	var vals: Array = d["values"] as Array
	var lv: int = level(id)
	return vals[lv] if lv < vals.size() else null


## attrEffectText(id, lv) sem i18n: "+8%" / "-10%" (menos tipografico "−") / "+0.09s".
func effect_text(id: String) -> String:
	var v: Variant = next_value(id)
	if v == null:
		return ""
	var f: float = float(v)
	if id == "speed_base":
		return "+%d%%" % roundi(f * 100.0)
	if id == "jump_cd":
		return "−%d%%" % roundi(f * 100.0)
	if id == "jump_ext":
		return "+%.2fs" % f
	return ""


## buyAttr(id): debita o mel do save, sobe o nivel, persiste. false se nao pode.
func buy(id: String) -> bool:
	var cost: int = next_cost(id)
	if cost < 0:
		return false
	var d: Dictionary = _data()
	if int(d.get("honey", 0)) < cost:
		return false
	d["honey"] = int(d.get("honey", 0)) - cost
	var attrs: Dictionary = d["attrs"] as Dictionary
	attrs[id] = int(attrs.get(id, 0)) + 1
	_do_persist()
	Events.attr_purchased.emit(id, int(attrs[id]))
	return true


func _do_persist() -> void:
	if _persist.is_valid():
		_persist.call()
	elif _use_save:
		Save.persist()


## Niveis para a GameRun (snapshot do save no inicio da run).
func levels() -> Dictionary:
	return (_data().get("attrs", {}) as Dictionary).duplicate()
