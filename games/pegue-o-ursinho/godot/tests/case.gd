extends RefCounted
## Base dos testes: scripts tests/test_*.gd estendem este arquivo e expoem funcoes test_*.

var failures: Array[String] = []
var checks: int = 0


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	checks += 1
	if actual != expected:
		failures.append("%s (obtido=%s esperado=%s)" % [msg, str(actual), str(expected)])


func near(actual: float, expected: float, msg: String, eps: float = 0.0001) -> void:
	checks += 1
	if absf(actual - expected) > eps:
		failures.append("%s (obtido=%s esperado=%s)" % [msg, str(actual), str(expected)])


func read_json(path: String) -> Variant:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		failures.append("arquivo ausente/vazio: " + path)
		return null
	return JSON.parse_string(text)
