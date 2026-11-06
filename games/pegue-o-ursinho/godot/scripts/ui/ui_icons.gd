class_name UiIcons
extends RefCounted
## Icones PLACEHOLDER da UI (o HTML usa emoji; a UI final nao). Cada icone e um TextureRect de nome
## estavel (`Icon` ou `*Icon`, grupo `ui_icon`): quadrado colorido + filho `Initial` (Label com a inicial). O ui-artist troca assim:
##   - solte res://art/ui/icons/<key>.png  (chave = id do buff/atributo, "honey", "ghost", "biome_3"...)
##     e o apply() usa a textura e esconde `Initial`; ou
##   - defina `texture` do no `Icon` direto na cena (apply() respeita texture ja definida).
## Chaves: buff id | atributo id | "biome_<id 1..10>" | "honey" | "ghost" | "bear" | "jump" |
##   "medal_1..3" | "fx_<speed|postjump|slow|invisible|phase|decoy|frozen|trapped|shield|rebound>".

const DIR: String = "res://art/ui/icons/"
const NEUTRAL: Color = Color("#E9A14D")

static var _tex_cache: Dictionary = {}   # "#hex" -> ImageTexture


static func rarity_color(rar: String) -> Color:
	return Color(BuffSystem.rarity_color(rar))


## Cor do placeholder de um atributo/efeito/etc.
static func color_for(key: String) -> Color:
	match key:
		"honey": return Color("#E9A14D")
		"ghost": return Color("#D9C8F0")
		"bear": return Color("#CD7B34")
		"jump": return Color("#6FD3CF")
		"medal_1": return Color("#F3DA9B")
		"medal_2": return Color("#D9C8F0")
		"medal_3": return Color("#CD7B34")
	if key.begins_with("biome_"):
		var idx: int = int(key.substr(6)) - 1
		if idx >= 0 and idx < GameState.biomes.size():
			return Color(str((GameState.biomes[idx] as Dictionary)["wallTint"]))
	return NEUTRAL


static func texture_for(color: Color) -> ImageTexture:
	var k: String = color.to_html(false)
	if _tex_cache.has(k):
		return _tex_cache[k] as ImageTexture
	var img: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var border: Color = color.darkened(0.45)
	for i in 8:
		img.set_pixel(i, 0, border)
		img.set_pixel(i, 7, border)
		img.set_pixel(0, i, border)
		img.set_pixel(7, i, border)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_tex_cache[k] = tex
	return tex


## Aplica o placeholder (ou a arte em art/ui/icons) a um TextureRect existente.
static func apply(icon: TextureRect, key: String, color: Color, letter: String) -> void:
	icon.add_to_group("ui_icon")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	if icon.custom_minimum_size == Vector2.ZERO:
		icon.custom_minimum_size = Vector2(40, 40)
	icon.tooltip_text = key
	icon.set_meta("icon_key", key)
	var initial: Label = icon.get_node_or_null("Initial") as Label
	var art_path: String = DIR + key + ".png"
	if ResourceLoader.exists(art_path):
		icon.texture = load(art_path) as Texture2D
		if initial != null:
			initial.visible = false
		return
	if icon.texture != null and not icon.has_meta("placeholder"):
		if initial != null:
			initial.visible = false   # o artista ja pos textura na cena
		return
	icon.texture = texture_for(color)
	icon.set_meta("placeholder", true)
	if initial == null:
		initial = Label.new()
		initial.name = "Initial"
		initial.set_anchors_preset(Control.PRESET_FULL_RECT)
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
		initial.add_theme_font_size_override("font_size", 16)
		initial.add_theme_color_override("font_color", Color("#310308"))
		initial.add_theme_constant_override("shadow_offset_x", 0)
		initial.add_theme_constant_override("shadow_offset_y", 0)
		icon.add_child(initial)
	initial.text = letter.substr(0, 1).to_upper()
	initial.visible = true


## Cria um novo `Icon`.
static func make(key: String, color: Color, letter: String, px: int = 40) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(px, px)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply(icon, key, color, letter)
	return icon


static func make_buff(buff_id: String, px: int = 40) -> TextureRect:
	var def: Dictionary = BuffSystem.buff_def(buff_id)
	var rar: String = str(def.get("rar", "comum"))
	return make(buff_id, rarity_color(rar), I18n.buff_name(buff_id), px)
