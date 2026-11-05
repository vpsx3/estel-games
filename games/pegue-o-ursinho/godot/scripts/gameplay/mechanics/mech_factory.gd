class_name MechFactory
extends RefCounted
## mechReset(): monta a mecanica do bioma. Ligada a GameRun.mech_factory por install().
## Config: level.config.mech (BiomeConfig editavel no Inspector) se preenchida; senao
## GameState.mech_config(idx) (data/legacy/biome_mech.json). Marcadores: level.get_mechanic_nodes().

static func make_for_type(t: String, run: GameRun, cfg: Dictionary, nodes: Array) -> MechBase:
	match t:
		"mushroom":
			return MechMushroom.new(run, cfg, nodes)
		"tide":
			return MechTide.new(run, cfg, nodes)
		"ice":
			return MechIce.new(run, cfg, nodes)
		"lily":
			return MechLily.new(run, cfg, nodes)
		"bats":
			return MechBats.new(run, cfg, nodes)
		"windows":
			return MechWindows.new(run, cfg, nodes)
		"castle":
			return MechCastle.new(run, cfg, nodes)
		"sky":
			return MechSky.new(run, cfg, nodes)
		"fire":
			return MechFire.new(run, cfg, nodes)
		"void":
			return MechVoid.new(run, cfg, nodes)
	return null


static func install(run: GameRun) -> void:
	run.mech_factory = MechFactory.create


static func config_for(run: GameRun, idx: int) -> Dictionary:
	var lvl: Object = run.level
	if lvl != null:
		var c: Variant = lvl.get("config")
		if c != null:
			var m: Variant = (c as Object).get("mech")
			if m is Dictionary and not (m as Dictionary).is_empty():
				return (m as Dictionary).duplicate()
	return GameState.mech_config(idx).duplicate()


static func create(run: GameRun, idx: int) -> Object:
	var cfg: Dictionary = config_for(run, idx)
	if cfg.is_empty():
		return null
	var nodes: Array = []
	if run.level != null and run.level.has_method("get_mechanic_nodes"):
		nodes = run.level.call("get_mechanic_nodes") as Array
	var m: MechBase = make_for_type(str(cfg.get("type", "")), run, cfg, nodes)
	if m == null:
		return null
	m.setup()
	return m
