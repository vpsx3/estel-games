extends "res://tests/case.gd"
## ScreenScaler.compute: pixel-perfect (integer) quando f>=1, fracionario quando f<1.

const Scaler := preload("res://autoload/screen_scaler.gd")


func _chk(size: Vector2i, integer: bool, scale: float) -> void:
	var r: Dictionary = Scaler.compute(size)
	eq(bool(r["integer"]), integer, "integer %s" % str(size))
	near(float(r["scale"]), scale, "scale %s" % str(size))
	near(float(r["factor"]), 1.0, "factor %s" % str(size))


func test_sizes() -> void:
	_chk(Vector2i(1920, 1080), true, 1.0)      # f=min(3.33,1.05)
	_chk(Vector2i(1366, 768), false, 0.75)     # f=0.75
	_chk(Vector2i(1024, 768), false, 0.75)     # f=0.75
	_chk(Vector2i(390, 844), false, 390.0 / 576.0)
	_chk(Vector2i(768, 1024), true, 1.0)       # f=1.0
	_chk(Vector2i(1152, 2048), true, 2.0)


func test_autoload_configures_window() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	check(tree.root.get_node_or_null("ScreenScaler") != null, "autoload ScreenScaler")
	eq(tree.root.content_scale_aspect, Window.CONTENT_SCALE_ASPECT_EXPAND, "aspect expand")
	eq(tree.root.content_scale_mode, Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "mode canvas_items")
