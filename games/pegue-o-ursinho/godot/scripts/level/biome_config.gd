@tool
class_name BiomeConfig
extends Resource
## Configuracao de um bioma (data/biomes/biome_XX.tres). Valores crus do legado
## (sem conversao de unidade; use Units em runtime). Editavel no Inspector.

@export var index: int = 0                 ## 0-based
@export var slug: String = ""              ## nome da pasta em assets/biomes (ex.: "01-floresta-encantada")
@export var name_pt: String = ""
@export var name_en: String = ""
@export var icon: String = ""              ## emoji legado (a UI final troca por icone PixelLab)
@export var wall_tint: Color = Color.WHITE
@export var bg_color: Color = Color.BLACK
@export var ghost_speed: float = 1.0       ## px/frame@60fps legado
@export var ghost_spawn_rate: float = 20.0 ## segundos legado
@export var mech_type: String = ""
@export var mech: Dictionary = {}          ## entrada crua de BIOME_MECH
@export_range(0.0, 1.0, 0.001) var target_wall_density: float = 0.4
@export var tileset: TileSet               ## tileset visual (dual-grid) do bioma
@export_file("*.json") var corner_map_path: String = ""  ## bitmask -> atlas coords (ver tilesets/corner_maps)
@export var detail_tiles: TileSet          ## opcional: variacoes de piso para DetalhePiso

@export_group("Regras do validador")
@export var min_spawn_dist: float = 10.0   ## celulas, urso <-> fantasma
@export var min_free_cells: int = 80
@export_range(0.0, 0.2, 0.001) var density_tolerance: float = 0.02
