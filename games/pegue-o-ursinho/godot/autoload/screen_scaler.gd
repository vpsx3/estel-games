extends Node
## Escala de tela: pixel-perfect quando cabe, fracionaria quando nao cabe (nunca corta).
## f = min(janela_w/BASE_W, janela_h/BASE_H)
##  - f >= 1: stretch INTEGER (escala floor(f))
##  - f <  1: stretch FRACTIONAL (escala f)
## Mode canvas_items + aspect expand sempre. content_scale_factor fica em 1.0: com
## content_scale_size definido o fator multiplicaria a escala do stretch (dupla escala).

const BASE_SIZE: Vector2i = Vector2i(576, 1024)


## Funcao pura. Retorna {"integer": bool, "scale": float (escala efetiva), "factor": float}.
static func compute(window_size: Vector2i) -> Dictionary:
	var f: float = minf(float(window_size.x) / float(BASE_SIZE.x), float(window_size.y) / float(BASE_SIZE.y))
	if f >= 1.0:
		return {"integer": true, "scale": floorf(f), "factor": 1.0}
	return {"integer": false, "scale": maxf(f, 0.01), "factor": 1.0}


func _ready() -> void:
	var w: Window = get_window()
	w.size_changed.connect(_apply)
	_apply()


func _apply() -> void:
	var w: Window = get_window()
	var r: Dictionary = compute(w.size)
	w.content_scale_size = BASE_SIZE
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	w.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if bool(r["integer"]) else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	w.content_scale_factor = float(r["factor"])
