extends Node
## Cliente do ranking (mesmo contrato da API legada; NAO alterar o contrato).
##   POST /api/session {game}                                        -> {token}
##   GET  /api/scores?game=                                          -> [..]
##   POST /api/scores {game,nick,seconds,ghosts,biomeReached,token}  -> {rank, scores}
## Falha silenciosa quando offline (token vazio, listas vazias).
## TODO(gameplay-porter): implementar com HTTPRequest; hoje e stub.

const GAME_ID: String = "pegue-o-ursinho"
const DEFAULT_BASE_URL: String = "https://estel.games"

var session_token: String = ""


## Base URL: no web usa a mesma origem da pagina; fora, DEFAULT_BASE_URL.
func base_url() -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("window.location.origin", true))
	return DEFAULT_BASE_URL


## Inicia a sessao anti-cheat e guarda o token. Retorna true se obteve token.
func start_session() -> bool:
	# TODO(gameplay-porter): POST base_url() + "/api/session" body {"game": GAME_ID}
	session_token = ""
	return false


## Retorna a lista de scores (vazia se falhar).
func load_scores() -> Array:
	# TODO(gameplay-porter): GET base_url() + "/api/scores?game=" + GAME_ID
	return []


## Envia o score. Retorna {"rank": null|int, "scores": Array}.
func save_score(_nick: String, _seconds: float, _ghosts: int, _biome_reached: int) -> Dictionary:
	# TODO(gameplay-porter): POST base_url() + "/api/scores"
	# body {game: GAME_ID, nick, seconds, ghosts, biomeReached: biome_reached, token: session_token}
	return {"rank": null, "scores": []}
