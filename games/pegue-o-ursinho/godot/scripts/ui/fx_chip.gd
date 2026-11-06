class_name FxChip
extends PanelContainer
## Chip de efeito ativo (fxchip). Filhos: Icon, NameLabel, TimeLabel, Bar (ProgressBar; some nos
## chips estaticos como Escudo/Rebote). Cor da barra via self_modulate de Bar.

@onready var icon: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var time_label: Label = %TimeLabel
@onready var bar: ProgressBar = %Bar

var key: String = ""


## Efeito com tempo: barra t/max (0..100).
func set_timed(p_key: String, p_name: String, t: float, tmax: float, color: Color) -> void:
	_icon(p_key, color, p_name)
	name_label.text = p_name
	time_label.text = "%.1fs" % t
	bar.visible = true
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = clampf(t / (tmax if tmax != 0.0 else 1.0) * 100.0, 0.0, 100.0)
	bar.self_modulate = color


## Chip estatico (Escudo xN / Rebote pronto).
func set_static(p_key: String, p_name: String, text: String, color: Color) -> void:
	_icon(p_key, color, p_name)
	name_label.text = p_name
	time_label.text = text
	bar.visible = false


func _icon(p_key: String, color: Color, p_name: String) -> void:
	if key != p_key:
		key = p_key
		UiIcons.apply(icon, "fx_" + p_key, color, p_name)
