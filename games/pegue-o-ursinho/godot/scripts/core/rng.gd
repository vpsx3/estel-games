class_name Rng
extends RefCounted
## Gerador aleatorio com seed opcional (testavel). Porta weightedPick/weightedOne do HTML.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


func randf() -> float:
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func chance(p: float) -> bool:
	return _rng.randf() < p


func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[_rng.randi_range(0, items.size() - 1)]


## Escolhe UM item por peso (campo `weight_key` de cada Dictionary). Equivale a weightedOne.
func weighted_one(items: Array, weight_key: String) -> Variant:
	if items.is_empty():
		return null
	var total: float = 0.0
	for it: Dictionary in items:
		total += float(it.get(weight_key, 0.0))
	var r: float = _rng.randf() * total
	for it: Dictionary in items:
		r -= float(it.get(weight_key, 0.0))
		if r <= 0.0:
			return it
	return items[items.size() - 1]


## Escolhe `n` itens distintos por peso. Equivale a weightedPick.
func weighted_pick(items: Array, weight_key: String, n: int) -> Array:
	var pool: Array = items.duplicate()
	var out: Array = []
	while out.size() < n and not pool.is_empty():
		var total: float = 0.0
		for it: Dictionary in pool:
			total += float(it.get(weight_key, 0.0))
		var r: float = _rng.randf() * total
		var idx: int = 0
		for i in pool.size():
			r -= float((pool[i] as Dictionary).get(weight_key, 0.0))
			if r <= 0.0:
				idx = i
				break
		out.append(pool[idx])
		pool.remove_at(idx)
	return out
