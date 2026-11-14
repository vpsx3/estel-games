extends SceneTree
## Simulador de balanceamento com bot (ponto de entrada). Ver balance_sim_core.gd.
## "$GODOT_PATH" --headless --path games/pegue-o-ursinho/godot --script res://tools/sim/balance_sim.gd -- --runs=200 --attr=0 --seed0=1 [--out=arquivo.json] [--max-s=900] [--quiet]
## (a implementacao fica em outro arquivo, carregado em runtime, porque os autoloads
## so existem depois que o SceneTree inicia e o script principal e compilado antes.)


func _initialize() -> void:
	await process_frame   # autoloads prontos
	var core: GDScript = load("res://tools/sim/balance_sim_core.gd") as GDScript
	if core == null:
		printerr("falha ao carregar balance_sim_core.gd")
		quit(1)
		return
	var sim: RefCounted = core.new() as RefCounted
	sim.call("run_sim")
	quit(0)
