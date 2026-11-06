extends Node
## Cliente do ranking (mesmo contrato da API legada; NAO alterar o contrato).
##   POST /api/session {game}                                        -> {token}
##   GET  /api/scores?game=                                          -> [..]
##   POST /api/scores {game,nick,seconds,ghosts,biomeReached,token}  -> {rank, scores}
## Falha silenciosa quando offline (token vazio, listas vazias). Porta startSession / loadScores /
## saveScore do index.html. A sessao e pedida ao INICIAR a run (startRun), nao antes.
##
## Base URL: web = origem da pagina (window.location.origin); fora do web = ProjectSettings
## `ursinho/api_base` (padrao https://estel.games).
## `transport` e injetavel (testes): func(method: String, url: String, body: Variant) -> Dictionary
## com {"ok": bool, "data": Variant}. O padrao usa HTTPRequest.

const GAME_ID: String = "pegue-o-ursinho"
const DEFAULT_BASE_URL: String = "https://estel.games"
const SETTING_BASE: String = "ursinho/api_base"
const TIMEOUT_S: float = 10.0

var session_token: String = ""
var transport: Callable = Callable()


## Base URL: no web usa a mesma origem da pagina; fora, a configuracao do projeto.
func base_url() -> String:
	if OS.has_feature("web"):
		return WebBridge.origin()
	var v: String = str(ProjectSettings.get_setting(SETTING_BASE, DEFAULT_BASE_URL))
	return v.trim_suffix("/")


## startSession(): obtem o token anti-cheat. Retorna true se obteve token.
func start_session() -> bool:
	session_token = ""
	var res: Dictionary = await _send("POST", "/api/session", {"game": GAME_ID})
	if bool(res.get("ok", false)) and res.get("data") is Dictionary:
		var tk: Variant = (res["data"] as Dictionary).get("token")
		if tk != null and str(tk) != "":
			session_token = str(tk)
	return session_token != ""


## loadScores(): lista de scores (vazia se falhar).
func load_scores() -> Array:
	var res: Dictionary = await _send("GET", "/api/scores?game=" + GAME_ID, null)
	if bool(res.get("ok", false)) and res.get("data") is Array:
		return res["data"] as Array
	return []


## saveScore(nick, seconds, ghosts, biomeReached). Retorna {"rank": null|int, "scores": Array}.
func save_score(nick: String, seconds: int, ghosts: int, biome_reached: String) -> Dictionary:
	var body: Dictionary = {
		"game": GAME_ID, "nick": nick, "seconds": seconds, "ghosts": ghosts,
		"biomeReached": biome_reached,
		"token": session_token if session_token != "" else null,
	}
	var res: Dictionary = await _send("POST", "/api/scores", body)
	if bool(res.get("ok", false)) and res.get("data") is Dictionary:
		return res["data"] as Dictionary
	return {"rank": null, "scores": []}


func _send(method: String, path: String, body: Variant) -> Dictionary:
	var url: String = base_url() + path
	var res: Variant
	if transport.is_valid():
		res = await transport.call(method, url, body)
	else:
		res = await _http(method, url, body)
	return res as Dictionary if res is Dictionary else {"ok": false, "data": null}


func _http(method: String, url: String, body: Variant) -> Dictionary:
	var req: HTTPRequest = HTTPRequest.new()
	req.timeout = TIMEOUT_S
	add_child(req)
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	var verb: int = HTTPClient.METHOD_POST if method == "POST" else HTTPClient.METHOD_GET
	var payload: String = "" if body == null else JSON.stringify(body)
	var err: int = req.request(url, headers, verb, payload)
	if err != OK:
		req.queue_free()
		return {"ok": false, "data": null}
	var out: Array = await req.request_completed   # [result, code, headers, body]
	req.queue_free()
	var good: bool = int(out[0]) == HTTPRequest.RESULT_SUCCESS and int(out[1]) >= 200 and int(out[1]) < 300
	if not good:
		return {"ok": false, "data": null}
	var text: String = (out[3] as PackedByteArray).get_string_from_utf8()
	return {"ok": true, "data": JSON.parse_string(text)}
