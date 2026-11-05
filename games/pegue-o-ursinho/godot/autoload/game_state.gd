extends Node
## Dados estaticos (data/legacy/*.json) + estado da run corrente.
## Todos os numeros de balanceamento vem do JSON; converta unidades com Units.

const LEGACY_DIR: String = "res://data/legacy/"

var maps: Array = []             # [bioma][linha][coluna] -> int (0 livre, 1 parede)
var biomes: Array = []           # Array[Dictionary]
var biome_mech: Dictionary = {}  # chaves "0".."9"
var ghost_types: Dictionary = {}
var buffs: Dictionary = {}       # {map_buffs, fixed_intervals, spray_slow_mult, spray_slow_dur, rarity_labels}
var attrs: Dictionary = {}       # {defs, order}
var constants: Dictionary = {}
var strings_pt: Dictionary = {}
var strings_en: Dictionary = {}

# Estado da run (equivale a currentBiome/cycleCount/phasesCleared do HTML).
var current_biome: int = 0
var cycle_count: int = 0
var phases_cleared: int = 0
var run_honey: int = 0
var elapsed: float = 0.0
var paused: bool = false


func _ready() -> void:
	load_all()


func load_all() -> void:
	maps = _normalize_maps(_read_json("maps.json") as Array)
	biomes = _read_json("biomes.json") as Array
	biome_mech = _read_json("biome_mech.json") as Dictionary
	ghost_types = _read_json("ghost_types.json") as Dictionary
	buffs = _read_json("buffs.json") as Dictionary
	attrs = _read_json("attrs.json") as Dictionary
	constants = _read_json("constants.json") as Dictionary
	strings_pt = _read_json("strings_pt.json") as Dictionary
	strings_en = _read_json("strings_en.json") as Dictionary


func reset_run() -> void:
	current_biome = 0
	cycle_count = 0
	phases_cleared = 0
	run_honey = 0
	elapsed = 0.0
	paused = false


## Constante legada pelo nome original (ex.: "HONEY_R"). Valor cru, SEM conversao de unidade.
func const_value(const_name: String, default: Variant = null) -> Variant:
	return constants.get(const_name, default)


func biome(idx: int) -> Dictionary:
	return biomes[idx] as Dictionary


func mech_config(idx: int) -> Dictionary:
	return biome_mech.get(str(idx), {}) as Dictionary


func map_rows(idx: int) -> Array:
	return maps[idx] as Array


## true se a celula e parede (fora do mapa conta como parede).
func is_wall(idx: int, c: int, r: int) -> bool:
	var rows: Array = maps[idx]
	if r < 0 or r >= rows.size():
		return true
	var row: Array = rows[r]
	if c < 0 or c >= row.size():
		return true
	return int(row[c]) == 1


func _read_json(file_name: String) -> Variant:
	var path: String = LEGACY_DIR + file_name
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("GameState: nao foi possivel ler " + path)
		return null
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("GameState: JSON invalido em " + path)
	return parsed


# JSON entrega floats; converte celulas para int.
func _normalize_maps(raw: Array) -> Array:
	var out: Array = []
	for grid: Array in raw:
		var g: Array = []
		for row: Array in grid:
			var r: Array = []
			for v: Variant in row:
				r.append(int(v))
			g.append(r)
		out.append(g)
	return out
