class_name UiScreen
extends Control
## Base das telas. Logica independente de estilo: textos fixos vem do metadado `i18n` dos nos
## (Label/Button -> text; LineEdit -> metadado `i18n_placeholder`) e sao reaplicados quando o idioma
## muda em runtime. Telas com texto dinamico sobrescrevem refresh().
## Mostrar/esconder = visible (a UI de fluxo, main_flow.gd, decide qual tela aparece).


func _ready() -> void:
	if not Events.language_changed.is_connected(_on_language_changed):
		Events.language_changed.connect(_on_language_changed)
	apply_texts()
	refresh()


func _exit_tree() -> void:
	if Events.language_changed.is_connected(_on_language_changed):
		Events.language_changed.disconnect(_on_language_changed)


func _on_language_changed(_lang: String) -> void:
	apply_texts()
	refresh()


## Reaplica os textos estaticos (metadado i18n).
func apply_texts() -> void:
	apply_texts_in(self)


static func apply_texts_in(node: Node) -> void:
	if node.has_meta("i18n"):
		node.set("text", I18n.t(str(node.get_meta("i18n"))))
	if node.has_meta("i18n_placeholder"):
		node.set("placeholder_text", I18n.t(str(node.get_meta("i18n_placeholder"))))
	for c: Node in node.get_children():
		apply_texts_in(c)


## Textos/valores dinamicos. Sobrescreva.
func refresh() -> void:
	pass


## Lista todos os textos visiveis (Label.text, Button.text, placeholder) da arvore. Util em testes.
static func collect_texts(node: Node, out: Array = []) -> Array:
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	elif node is LineEdit:
		out.append((node as LineEdit).placeholder_text)
		out.append((node as LineEdit).text)
	for c: Node in node.get_children():
		collect_texts(c, out)
	return out
