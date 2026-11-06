extends SceneTree
## Roda todos os tests/test_*.gd (funcoes test_*). Saida != 0 se algo falhar.
## Uso: "$GODOT_PATH" --headless --path games/pegue-o-ursinho/godot --script res://tests/run_all.gd

func _initialize() -> void:
	await process_frame  # autoloads rodam _ready antes dos testes
	var total_fail: int = 0
	var total_pass: int = 0
	var files: PackedStringArray = []
	var dir: DirAccess = DirAccess.open("res://tests")
	if dir == null:
		printerr("FAIL: nao foi possivel abrir res://tests")
		quit(1)
		return
	for f: String in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	for f: String in files:
		var script: GDScript = load("res://tests/" + f) as GDScript
		if script == null:
			print("FAIL  %s (erro de parse/carga)" % f)
			total_fail += 1
			continue
		var names: PackedStringArray = []
		for m: Dictionary in script.get_script_method_list():
			var mn: String = m["name"]
			if mn.begins_with("test_"):
				names.append(mn)
		names.sort()
		for mn: String in names:
			var inst: RefCounted = script.new() as RefCounted
			await inst.call(mn)   # testes async (E4c) tambem sao aguardados
			var fails: Array = inst.get("failures")
			if fails.is_empty():
				print("PASS  %s::%s (%d checks)" % [f, mn, int(inst.get("checks"))])
				total_pass += 1
			else:
				total_fail += 1
				print("FAIL  %s::%s" % [f, mn])
				for msg: String in fails:
					print("        - " + msg)
	print("--- %d passed, %d failed ---" % [total_pass, total_fail])
	quit(1 if total_fail > 0 else 0)
