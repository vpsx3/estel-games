extends "res://tests/case.gd"
## Save (formato do HTML, round-trip, campos desconhecidos) e ApiClient (contrato com transporte mock).

const TMP: String = "user://_test_save.json"


func test_save_default_format() -> void:
	var d: Dictionary = Save.default_save()
	check(d.keys() == ["honey", "attrs", "skins"], "ordem honey, attrs, skins")
	eq(Save.WEB_KEY, "estel_pou_save", "chave web")
	eq(Save.FILE_PATH, "user://save.json", "arquivo fora do web")


func test_parse_html_save_and_preserve_unknown() -> void:
	var raw: String = '{"honey":123,"attrs":{"speed_base":3,"jump_cd":1,"futuro":7},"skins":{"owned":["default","azul"],"equipped":"azul"},"extra":{"a":[1,2]}}'
	var d: Dictionary = Save.parse_text(raw)
	eq(d["honey"], 123, "honey")
	eq((d["attrs"] as Dictionary)["speed_base"], 3, "attr")
	eq((d["attrs"] as Dictionary)["double_jump"], 0, "attr ausente => default")
	eq((d["attrs"] as Dictionary)["futuro"], 7, "attr desconhecido preservado")
	eq((d["skins"] as Dictionary)["equipped"], "azul", "skin equipada")
	check(d.has("extra"), "campo de topo desconhecido preservado")
	# round-trip: reler o que gravamos da o mesmo conteudo e ints continuam ints
	var again: Dictionary = Save.parse_text(Save.to_text(d))
	eq(again, d, "round-trip identico")
	check(not Save.to_text(d).contains("123.0"), "sem float para inteiro")


func test_parse_invalid_falls_back() -> void:
	eq(Save.parse_text(""), Save.default_save(), "vazio")
	eq(Save.parse_text("{nao json"), Save.default_save(), "invalido")
	eq(Save.parse_text("[1,2]"), Save.default_save(), "nao-objeto")
	var d: Dictionary = Save.parse_text('{"honey":"abc"}')
	eq(d["honey"], 0, "honey nao numerico => 0")


func test_save_file_roundtrip() -> void:
	var old_path: String = Save.file_path
	var old_data: Dictionary = Save.data
	Save.file_path = TMP
	Save.data = Save.default_save()
	Save.add_honey(40)
	(Save.data["attrs"] as Dictionary)["reroll"] = 1
	Save.data["custom"] = "x"
	Save.persist()
	Save.data = {}
	Save.load_save()
	eq(Save.honey(), 40, "mel persistido")
	eq(Save.attr_level("reroll"), 1, "atributo persistido")
	eq(Save.data.get("custom"), "x", "campo desconhecido persistido")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	Save.file_path = old_path
	Save.data = old_data


func _mock(log: Array, responses: Dictionary) -> Callable:
	return func(method: String, url: String, body: Variant) -> Dictionary:
		log.append({"method": method, "url": url, "body": body})
		for k: String in responses:
			if url.ends_with(k):
				return responses[k]
		return {"ok": false, "data": null}


func test_api_contract() -> void:
	var log: Array = []
	ApiClient.transport = _mock(log, {
		"/api/session": {"ok": true, "data": {"token": "abc"}},
		"/api/scores?game=pegue-o-ursinho": {"ok": true, "data": [{"nick": "A", "seconds": 10, "ghosts": 2}]},
		"/api/scores": {"ok": true, "data": {"rank": 1, "scores": []}},
	})
	var base: String = ApiClient.base_url()
	check(base.begins_with("http"), "base url")
	check(await ApiClient.start_session(), "sessao obtida")
	eq(ApiClient.session_token, "abc", "token")
	eq(log[0]["method"], "POST", "POST session")
	eq(log[0]["url"], base + "/api/session", "url session")
	eq(log[0]["body"], {"game": "pegue-o-ursinho"}, "body session")
	var scores: Array = await ApiClient.load_scores()
	eq(scores.size(), 1, "scores")
	eq(log[1]["method"], "GET", "GET scores")
	eq(log[1]["url"], base + "/api/scores?game=pegue-o-ursinho", "url scores")
	var res: Dictionary = await ApiClient.save_score("Nick", 95, 4, "Floresta Encantada")
	eq(res["rank"], 1, "rank")
	eq(log[2]["body"], {"game": "pegue-o-ursinho", "nick": "Nick", "seconds": 95, "ghosts": 4,
		"biomeReached": "Floresta Encantada", "token": "abc"}, "payload do score")
	ApiClient.transport = Callable()
	ApiClient.session_token = ""


func test_api_offline_is_silent() -> void:
	ApiClient.transport = func(_m: String, _u: String, _b: Variant) -> Dictionary: return {"ok": false, "data": null}
	check(not await ApiClient.start_session(), "sem token offline")
	eq(ApiClient.session_token, "", "token vazio")
	eq((await ApiClient.load_scores()).size(), 0, "lista vazia")
	var res: Dictionary = await ApiClient.save_score("A", 1, 1, "x")
	eq(res, {"rank": null, "scores": []}, "fallback do saveScore")
	ApiClient.transport = Callable()


func test_api_null_token_in_payload() -> void:
	var log: Array = []
	ApiClient.transport = _mock(log, {"/api/scores": {"ok": true, "data": {"rank": 2, "scores": []}}})
	ApiClient.session_token = ""
	await ApiClient.save_score("A", 1, 1, "x")
	eq(log[0]["body"]["token"], null, "token null sem sessao (como sessionToken=null)")
	ApiClient.transport = Callable()


func test_api_base_setting() -> void:
	eq(str(ProjectSettings.get_setting("ursinho/api_base", "")), "https://estel.games", "ursinho/api_base")
	eq(ApiClient.base_url(), "https://estel.games", "base url fora do web")
