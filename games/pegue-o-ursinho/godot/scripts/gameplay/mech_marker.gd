@tool
class_name MechMarker
extends Node2D
## Marcador de mecanica posicionavel (scenes/mechanics/*.tscn). Arraste para LevelRoot/Mecanicas:
## com pelo menos 1 marcador do tipo, a mecanica usa SO as posicoes colocadas a mao; sem nenhum,
## o jogo gera proceduralmente como o original. Valores -1 = usar o numero do BiomeConfig.mech.
## No jogo o sprite do marcador some (a mecanica desenha a versao animada).
## Mare, gelo e inversao do vazio sao so configuracao (nao ha marcador).

@export_enum("mushroom", "lilypad", "bat_spawn", "window", "gate", "carpet", "platform", "wind", "geyser", "portal") var kind: String = "mushroom"

@export_group("Cogumelo")
@export var dist: int = -1                 ## celulas lancadas (-1 = config)

@export_group("Janela (parede)")
@export var radius_cells: float = -1.0     ## alcance de espreita em celulas (-1 = config)
@export var telegraph: float = -1.0        ## s ate o fantasma sair (-1 = config)
@export var cooldown: float = -1.0         ## s entre fantasmas (-1 = config)

@export_group("Grade / plataforma / gêiser")
@export var phase: float = -1.0            ## fase do movimento em rad (-1 = automatica/sorteada)

@export_group("Plataforma")
@export_enum("h", "v") var axis: String = "h"
@export var range_cells: int = -1          ## deslocamento +- em celulas (-1 = config)

@export_group("Tapete / vento")
@export var length_cells: int = 3          ## comprimento em celulas (tapete: para a direita)
@export var wind_dir: Vector2i = Vector2i.RIGHT   ## direcao da corrente de ar


func _process(_dt: float) -> void:
	# editor: encaixa no centro da celula (bat_spawn fica livre)
	if Engine.is_editor_hint() and kind != "bat_spawn":
		var c: Vector2i = Vector2i(floori(position.x / Units.TILE), floori(position.y / Units.TILE))
		var snapped_pos: Vector2 = Units.cell_center(c.x, c.y)
		if position != snapped_pos:
			position = snapped_pos
