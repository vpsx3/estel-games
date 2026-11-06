class_name WaterOverlay
extends Node2D
## Camada de agua da mare (bioma 2): desenha as celulas alagadas atras da WorldView com um shader simples
## (assets/mechanics/water/water_flow.gdshader): frames do water_tile + scroll + brilho (shimmer).

const ATLAS: String = "res://assets/mechanics/water/water_frames_atlas.png"
const SHADER: String = "res://assets/mechanics/water/water_flow.gdshader"

var _cells: Array = []
var _atlas: Texture2D
var _mat: ShaderMaterial


func _init() -> void:
	show_behind_parent = true   # fica sob o desenho da WorldView (orbes, mel, espuma)
	if ResourceLoader.exists(ATLAS) and ResourceLoader.exists(SHADER):
		_atlas = load(ATLAS) as Texture2D
		_mat = ShaderMaterial.new()
		_mat.shader = load(SHADER) as Shader
		material = _mat


func set_state(cells: Array, t: float) -> void:
	_cells = cells
	if _mat != null:
		_mat.set_shader_parameter("t", t)
	queue_redraw()


func _draw() -> void:
	for cell: Vector2i in _cells:
		var r: Rect2 = Rect2(cell.x * Units.TILE, cell.y * Units.TILE, Units.TILE, Units.TILE)
		if _atlas != null:
			draw_texture_rect(_atlas, r, false)
		else:
			draw_rect(r, Color(0.157, 0.43, 0.78, 0.8))
