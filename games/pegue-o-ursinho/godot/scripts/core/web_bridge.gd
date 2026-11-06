class_name WebBridge
extends RefCounted
## Acesso ao navegador SEM JavaScriptBridge.eval (a CSP do build web nao permite 'unsafe-eval').
## Usa JavaScriptBridge.get_interface(). Fora do web todas as funcoes devolvem o valor neutro.


static func _iface(name: String) -> JavaScriptObject:
	if not OS.has_feature("web"):
		return null
	return JavaScriptBridge.get_interface(name)


## localStorage.getItem(key); "" se ausente ou indisponivel.
static func ls_get(key: String) -> String:
	var ls: JavaScriptObject = _iface("localStorage")
	if ls == null:
		return ""
	var v: Variant = ls.getItem(key)
	return "" if v == null else str(v)


static func ls_set(key: String, value: String) -> void:
	var ls: JavaScriptObject = _iface("localStorage")
	if ls != null:
		ls.setItem(key, value)


## window.location.origin
static func origin() -> String:
	var loc: JavaScriptObject = _iface("location")
	return "" if loc == null else str(loc.origin)


## window.prompt(message, default): caixa de texto nativa do navegador (abre o teclado do celular).
## Devolve null se o jogador cancelar ou fora do web.
static func prompt(message: String, default_text: String = "") -> Variant:
	var win: JavaScriptObject = _iface("window")
	if win == null:
		return null
	var v: Variant = win.prompt(message, default_text)
	return null if v == null else str(v)


## navigator.language
static func nav_language() -> String:
	var nav: JavaScriptObject = _iface("navigator")
	if nav == null:
		return ""
	var v: Variant = nav.language
	return "" if v == null else str(v)


## Mesmo criterio do HTML: matchMedia('(pointer:coarse)').matches || ('ontouchstart' in window).
static func is_coarse_pointer() -> bool:
	var win: JavaScriptObject = _iface("window")
	if win == null:
		return false
	var mq: Variant = win.matchMedia("(pointer:coarse)")
	if mq is JavaScriptObject and bool((mq as JavaScriptObject).matches):
		return true
	# 'ontouchstart' in window nao e expressavel sem eval (a propriedade existe com valor null);
	# navigator.maxTouchPoints > 0 e o equivalente pratico.
	var nav: JavaScriptObject = _iface("navigator")
	return nav != null and int(nav.maxTouchPoints) > 0
