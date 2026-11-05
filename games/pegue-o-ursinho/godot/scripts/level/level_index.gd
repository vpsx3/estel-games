class_name LevelIndex
extends RefCounted
## Indice das 10 fases. Caminhos derivados de BIOME_SLUGS (data/legacy/constants.json).

const SLUGS: Array[String] = [
	"01-floresta-encantada", "02-praia-dos-coqueiros", "03-montanha-gelada", "04-pantano-verde",
	"05-caverna-dos-ecos", "06-vila-assombrada", "07-castelo-do-rei", "08-ilhas-flutuantes",
	"09-inferno-fofo", "10-dimensao-dos-fantasmas",
]


static func count() -> int:
	return SLUGS.size()


static func scene_path(i: int) -> String:
	return "res://levels/biome_%s.tscn" % SLUGS[i].replace("-", "_")


static func config_path(i: int) -> String:
	return "res://data/biomes/biome_%02d.tres" % (i + 1)
