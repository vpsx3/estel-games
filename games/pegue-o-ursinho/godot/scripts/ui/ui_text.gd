class_name UiText
extends RefCounted
## Utilitarios de texto da UI. strip_emoji: a UI final nao usa emoji (criterio de aceite);
## os dados legados ficam intactos e o texto e limpo na saida do I18n.


static func is_emoji_like(cp: int) -> bool:
	return (cp >= 0x1F000 and cp <= 0x1FFFF) \
		or (cp >= 0x2190 and cp <= 0x21FF) \
		or (cp >= 0x2300 and cp <= 0x23FF) \
		or (cp >= 0x25A0 and cp <= 0x25FF) \
		or (cp >= 0x2600 and cp <= 0x27BF) \
		or (cp >= 0x2900 and cp <= 0x297F) \
		or (cp >= 0x2B00 and cp <= 0x2BFF) \
		or cp == 0xFE0F or cp == 0x200D or cp == 0x20E3


static func has_emoji(s: String) -> bool:
	for i in s.length():
		if is_emoji_like(s.unicode_at(i)):
			return true
	return false


## Remove emoji/simbolos; se removeu algo, apara as bordas (espacos que sobraram).
static func strip_emoji(s: String) -> String:
	if not has_emoji(s):
		return s
	var out: String = ""
	for i in s.length():
		var cp: int = s.unicode_at(i)
		if not is_emoji_like(cp):
			out += char(cp)
	return out.strip_edges()


## formatTime(s): m:ss
static func format_time(seconds: float) -> String:
	var s: int = floori(seconds)
	return "%d:%02d" % [s / 60, s % 60]
