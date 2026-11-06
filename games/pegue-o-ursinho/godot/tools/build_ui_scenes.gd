extends SceneTree
## Gera scenes/ui/*.tscn e scenes/main.tscn (ESQUELETO inicial da E4c). Uso unico:
##   "$GODOT_PATH" --headless --path games/pegue-o-ursinho/godot --script res://tools/build_ui_scenes.gd
## ATENCAO: depois que o ui-artist comecar a editar os .tscn, NAO rode de novo (sobrescreve).
## Nomes de no estaveis (unique_name_in_owner) sao o contrato com scripts/ui/*.gd.

const OUT: String = "res://scenes/ui/"
const SCR: String = "res://scripts/ui/"

var scene_root: Node = null


func _initialize() -> void:
	await process_frame   # autoloads (I18n) prontos
	_lang_toggle()
	_fx_chip()
	_passive_chip()
	_upgrade_card()
	_ranking_row()
	_buff_card()
	_nick()
	_menu()
	_upgrades()
	_ranking()
	_buff_select()
	_world_choice()
	_result()
	_pause()
	_hud()
	_main()
	print("ui scenes geradas")
	quit()


# ---------------------------------------------------------------- helpers
func _t(key: String) -> String:
	return str(root.get_node("I18n").call("t", key))


func _tf(key: String, p: Dictionary) -> String:
	return str(root.get_node("I18n").call("tf", key, p))


func _add(parent: Node, node: Node, node_name: String, unique: bool = false) -> Node:
	node.name = node_name
	parent.add_child(node)
	node.owner = scene_root
	if unique:
		node.unique_name_in_owner = true
	return node


func _ignore(c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _label(parent: Node, node_name: String, i18n: String = "", variation: String = "", center: bool = true, wrap: bool = false) -> Label:
	var l: Label = Label.new()
	_add(parent, l, node_name, true)
	_ignore(l)
	if i18n != "":
		l.set_meta("i18n", i18n)
		l.text = _t(i18n)
	if variation != "":
		l.theme_type_variation = StringName(variation)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(parent: Node, node_name: String, i18n: String = "", min_h: float = 56.0, min_w: float = 0.0) -> Button:
	var b: Button = Button.new()
	_add(parent, b, node_name, true)
	b.custom_minimum_size = Vector2(min_w, min_h)
	if i18n != "":
		b.set_meta("i18n", i18n)
		b.text = _t(i18n)
	return b


func _box(parent: Node, node_name: String, vertical: bool, sep: int = 12, unique: bool = false) -> BoxContainer:
	var b: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	_add(parent, b, node_name, unique)
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _icon(parent: Node, node_name: String, px: int) -> TextureRect:
	var t: TextureRect = TextureRect.new()
	_add(parent, t, node_name, true)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ignore(t)
	return t


func _instance(parent: Node, path: String, node_name: String) -> Node:
	var ps: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var inst: Node = ps.instantiate()
	_add(parent, inst, node_name, true)
	return inst


func _new_root(node: Node, script_name: String, node_name: String) -> void:
	scene_root = node
	scene_root.name = node_name
	if script_name != "":
		scene_root.set_script(load(SCR + script_name))


func _save(file: String) -> void:
	var ps: PackedScene = PackedScene.new()
	var err: int = ps.pack(scene_root)
	if err != OK:
		printerr("pack falhou: ", file, " ", err)
	err = ResourceSaver.save(ps, OUT + file)
	if err != OK:
		printerr("save falhou: ", file, " ", err)
	scene_root.free()
	scene_root = null


## Tela cheia: Background (escurece e bloqueia cliques) + Margin + Content (VBox centralizado).
func _screen(node_name: String, script_name: String, center: bool = true) -> VBoxContainer:
	var r: Control = Control.new()
	_new_root(r, script_name, node_name)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	_add(r, bg, "Background")
	bg.color = Color(0.1922, 0.0118, 0.0314, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m: MarginContainer = MarginContainer.new()
	_add(r, m, "Margin")
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 28)
	var v: VBoxContainer = VBoxContainer.new()
	_add(m, v, "Content")
	v.add_theme_constant_override("separation", 16)
	if center:
		v.alignment = BoxContainer.ALIGNMENT_CENTER
	return v


func _scroll(parent: Node, node_name: String) -> ScrollContainer:
	var s: ScrollContainer = ScrollContainer.new()
	_add(parent, s, node_name)
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return s


# ---------------------------------------------------------------- componentes
func _lang_toggle() -> void:
	var h: HBoxContainer = HBoxContainer.new()
	_new_root(h, "lang_toggle.gd", "LangToggle")
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	var en: Button = _button(h, "EN", "", 48.0, 64.0)
	en.text = "EN"
	en.toggle_mode = true
	var sep: Label = _label(h, "Sep")
	sep.text = "|"
	var pt: Button = _button(h, "PT", "", 48.0, 64.0)
	pt.text = "PT"
	pt.toggle_mode = true
	_save("lang_toggle.tscn")


func _fx_chip() -> void:
	var p: PanelContainer = PanelContainer.new()
	_new_root(p, "fx_chip.gd", "FxChip")
	_ignore(p)
	p.custom_minimum_size = Vector2(250, 0)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var h: BoxContainer = _box(p, "Row", false, 8)
	_icon(h, "Icon", 32)
	var v: BoxContainer = _box(h, "Info", true, 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top: BoxContainer = _box(v, "Top", false, 8)
	var n: Label = _label(top, "NameLabel", "", "", false)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(top, "TimeLabel", "", "", false)
	var bar: ProgressBar = ProgressBar.new()
	_add(v, bar, "Bar", true)
	bar.custom_minimum_size = Vector2(0, 8)
	bar.show_percentage = false
	_ignore(bar)
	_save("fx_chip.tscn")


func _passive_chip() -> void:
	var p: PanelContainer = PanelContainer.new()
	_new_root(p, "passive_chip.gd", "PassiveChip")
	_ignore(p)
	var h: BoxContainer = _box(p, "Row", false, 6)
	_icon(h, "Icon", 32)
	_label(h, "CooldownLabel", "", "", false)
	_save("passive_chip.tscn")


func _upgrade_card() -> void:
	var p: PanelContainer = PanelContainer.new()
	_new_root(p, "upgrade_card.gd", "UpgradeCard")
	var h: BoxContainer = _box(p, "Row", false, 12)
	_icon(h, "Icon", 48)
	var v: BoxContainer = _box(h, "Info", true, 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n: Label = _label(v, "NameLabel", "", "", false)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(v, "MetaLabel", "", "DimLabel", false)
	_button(h, "BuyButton", "", 64.0, 130.0)
	_save("upgrade_card.tscn")


func _ranking_row() -> void:
	var p: PanelContainer = PanelContainer.new()
	_new_root(p, "ranking_row.gd", "RankingRow")
	_ignore(p)
	var h: BoxContainer = _box(p, "Row", false, 8)
	_icon(h, "Medal", 32)
	var r: Label = _label(h, "RankLabel", "", "", false)
	r.custom_minimum_size = Vector2(52, 0)
	var n: Label = _label(h, "NickLabel", "", "", false)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	var b: Label = _label(h, "NewBadge", "badge_new", "DimLabel", false)
	b.visible = false
	var t: Label = _label(h, "TimeLabel", "", "", false)
	t.custom_minimum_size = Vector2(70, 0)
	var g: Label = _label(h, "GhostsLabel", "", "", false)
	g.custom_minimum_size = Vector2(40, 0)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_save("ranking_row.tscn")


func _buff_card() -> void:
	var b: Button = Button.new()
	_new_root(b, "buff_card.gd", "BuffCard")
	b.toggle_mode = true
	b.theme_type_variation = &"BuffCard"
	b.custom_minimum_size = Vector2(0, 118)
	var m: MarginContainer = MarginContainer.new()
	_add(b, m, "Margin")
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 8)
	var h: BoxContainer = _box(m, "Row", false, 10)
	var s: Label = _label(h, "SelNum", "", "HudBigLabel", true)
	s.custom_minimum_size = Vector2(28, 0)
	s.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon(h, "Icon", 56)
	var v: BoxContainer = _box(h, "Info", true, 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_label(v, "NameLabel", "", "", false)
	var d: Label = _label(v, "DescLabel", "", "DimLabel", false, true)
	d.custom_minimum_size = Vector2(300, 0)
	var tags: BoxContainer = _box(v, "Tags", false, 12)
	_label(tags, "RarityLabel", "", "RarityComum", false)
	_label(tags, "TypeLabel", "", "DimLabel", false)
	_save("buff_card.tscn")


# ---------------------------------------------------------------- telas
func _nick() -> void:
	var v: VBoxContainer = _screen("NickScreen", "nick_screen.gd")
	_label(v, "Title", "screenNickTitle", "TitleLabel")
	_icon(v, "Icon", 96)
	_label(v, "Desc", "screenNickDesc", "", true, true)
	var le: LineEdit = LineEdit.new()
	_add(v, le, "NickInput", true)
	le.max_length = 16
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	le.custom_minimum_size = Vector2(0, 56)
	le.set_meta("i18n_placeholder", "nickPlaceholder")
	le.placeholder_text = _t("nickPlaceholder")
	_button(v, "PlayButton", "btnPlay")
	_button(v, "RankingButton", "btnShowRanking")
	_instance(v, OUT + "lang_toggle.tscn", "LangToggle")
	_save("nick_screen.tscn")


func _menu() -> void:
	var v: VBoxContainer = _screen("MenuScreen", "menu_screen.gd")
	_label(v, "Title", "screenNickTitle", "TitleLabel")
	var hr: BoxContainer = _box(v, "HoneyRow", false, 8)
	hr.alignment = BoxContainer.ALIGNMENT_CENTER
	_icon(hr, "HoneyIcon", 40)
	_label(hr, "HoneyLabel", "", "HudBigLabel", false)
	_button(v, "PlayButton", "menuPlay")
	_button(v, "UpgradesButton", "menuUpgrades")
	_button(v, "SkinsButton", "menuSkins")
	_button(v, "RankingButton", "menuRanking")
	_instance(v, OUT + "lang_toggle.tscn", "LangToggle")
	_save("menu_screen.tscn")


func _upgrades() -> void:
	var v: VBoxContainer = _screen("UpgradesScreen", "upgrades_screen.gd", false)
	_label(v, "Title", "upgradesTitle", "HeaderLabel")
	var br: BoxContainer = _box(v, "BalanceRow", false, 8)
	br.alignment = BoxContainer.ALIGNMENT_CENTER
	_icon(br, "BalanceIcon", 40)
	_label(br, "BalanceLabel", "", "HudBigLabel", false)
	var sc: ScrollContainer = _scroll(v, "Scroll")
	var list: VBoxContainer = VBoxContainer.new()
	_add(sc, list, "List", true)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	_button(v, "BackButton", "btnBackRanking")
	_save("upgrades_screen.tscn")


func _ranking() -> void:
	var v: VBoxContainer = _screen("RankingScreen", "ranking_screen.gd", false)
	_label(v, "Title", "rankingSubtitle", "HeaderLabel")
	var hd: BoxContainer = _box(v, "Header", false, 8)
	var pad: Control = Control.new()
	_add(hd, pad, "Pad")
	pad.custom_minimum_size = Vector2(40, 0)
	var hr: Label = _label(hd, "HeaderRank", "", "DimLabel", false)
	hr.text = "#"
	hr.custom_minimum_size = Vector2(52, 0)
	var hp: Label = _label(hd, "HeaderPlayer", "rankingColPlayer", "DimLabel", false)
	hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ht: Label = _label(hd, "HeaderTime", "rankingColTime", "DimLabel", false)
	ht.custom_minimum_size = Vector2(70, 0)
	var gi: TextureRect = _icon(hd, "GhostHeaderIcon", 28)
	gi.custom_minimum_size = Vector2(40, 28)
	_label(v, "StatusLabel", "rankingLoading", "", true, true)
	var sc: ScrollContainer = _scroll(v, "Scroll")
	var rows: VBoxContainer = VBoxContainer.new()
	_add(sc, rows, "Rows", true)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	_button(v, "BackButton", "btnBackRanking")
	_save("ranking_screen.tscn")


func _buff_select() -> void:
	var v: VBoxContainer = _screen("BuffSelectScreen", "buff_select_screen.gd", false)
	v.add_theme_constant_override("separation", 10)
	_label(v, "Title", "buffScreenTitle", "HeaderLabel")
	_label(v, "SubLabel", "buffScreenSub", "DimLabel")
	var sc: ScrollContainer = _scroll(v, "Scroll")
	var cards: VBoxContainer = VBoxContainer.new()
	_add(sc, cards, "Cards", true)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 8)
	var sb: Button = _button(v, "StartButton", "", 60.0)
	sb.text = _tf("btn_start_run", {"n": 0})
	_save("buff_select_screen.tscn")


func _world_choice() -> void:
	var v: VBoxContainer = _screen("WorldChoiceScreen", "world_choice_screen.gd")
	_label(v, "Title", "worldChoiceTitle", "HeaderLabel")
	var cards: VBoxContainer = VBoxContainer.new()
	_add(v, cards, "Cards", true)
	cards.add_theme_constant_override("separation", 8)
	var rb: Button = _button(v, "RerollButton", "btnReroll")
	rb.visible = false
	_save("world_choice_screen.tscn")


func _result() -> void:
	var v: VBoxContainer = _screen("ResultScreen", "result_screen.gd")
	v.add_theme_constant_override("separation", 10)
	_icon(v, "GhostIcon", 64)
	_label(v, "Title", "result_title", "HeaderLabel")
	_label(v, "TimeLabel", "", "BigTimeLabel")
	_label(v, "GhostsLabel")
	var br: BoxContainer = _box(v, "BuildRow", false, 8)
	br.alignment = BoxContainer.ALIGNMENT_CENTER
	_label(br, "BuildLabel", "build_label", "DimLabel", false)
	var bi: BoxContainer = _box(br, "BuildIcons", false, 4)
	bi.name = "BuildIcons"
	bi.unique_name_in_owner = true
	_label(v, "HoneyLabel")
	_label(v, "BiomeLabel", "", "", true, true)
	_label(v, "RankMsgLabel", "", "", true, true)
	_button(v, "PlayAgainButton", "btnPlayAgain")
	_button(v, "MenuButton", "btnResultMenu")
	_button(v, "RankingButton", "btnResultRanking")
	_save("result_screen.tscn")


func _pause() -> void:
	var v: VBoxContainer = _screen("PauseScreen", "pause_screen.gd")
	_label(v, "Title", "pause_title", "HeaderLabel")
	_button(v, "ResumeButton", "btn_continue")
	_button(v, "MenuButton", "btn_quit_menu")
	_instance(v, OUT + "lang_toggle.tscn", "LangToggle")
	_save("pause_screen.tscn")


func _hud() -> void:
	var r: Control = Control.new()
	_new_root(r, "hud.gd", "Hud")
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ignore(r)
	var m: MarginContainer = MarginContainer.new()
	_add(r, m, "TopMargin")
	m.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_ignore(m)
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10)
	var top: BoxContainer = _box(m, "Top", true, 6)
	var row: BoxContainer = _box(top, "Row", false, 12)
	var tl: Label = _label(row, "TimerLabel", "", "HudBigLabel", false)
	tl.text = "0:00"
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gb: BoxContainer = _box(row, "GhostBox", false, 4)
	_icon(gb, "GhostIcon", 32)
	_label(gb, "GhostCountLabel", "", "HudBigLabel", false)
	var hb: BoxContainer = _box(row, "HoneyBox", false, 4)
	_icon(hb, "HoneyIcon", 32)
	_label(hb, "HoneyLabel", "", "HudBigLabel", false)
	var pb: Button = _button(row, "PauseButton", "pause_button", 56.0, 96.0)
	pb.mouse_filter = Control.MOUSE_FILTER_STOP
	_label(top, "BiomeLabel", "", "DimLabel", false)
	var pl: BoxContainer = _box(top, "PassiveList", false, 6)
	pl.name = "PassiveList"
	pl.unique_name_in_owner = true
	var fl: BoxContainer = _box(top, "FxList", true, 4)
	fl.name = "FxList"
	fl.unique_name_in_owner = true
	var w: Label = _label(r, "WarningLabel", "", "WarningLabel", true, true)
	w.anchor_left = 0.0
	w.anchor_right = 1.0
	w.anchor_top = 0.30
	w.anchor_bottom = 0.30
	w.offset_top = -40
	w.offset_bottom = 40
	w.offset_left = 16
	w.offset_right = -16
	w.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var bn: VBoxContainer = VBoxContainer.new()
	_add(r, bn, "Banner", true)
	bn.anchor_left = 0.0
	bn.anchor_right = 1.0
	bn.anchor_top = 0.36
	bn.anchor_bottom = 0.36
	bn.offset_left = 16
	bn.offset_right = -16
	bn.offset_top = -10
	bn.offset_bottom = 110
	bn.add_theme_constant_override("separation", 4)
	_ignore(bn)
	_icon(bn, "BiomeIcon", 64)
	_label(bn, "BannerName", "", "TitleLabel")
	_label(bn, "BannerSub", "", "DimLabel")
	_save("hud.tscn")


func _main() -> void:
	var n: Node = Node.new()
	_new_root(n, "main_flow.gd", "Main")
	_add(n, Node.new(), "GameHolder", true)
	var cl: CanvasLayer = CanvasLayer.new()
	_add(n, cl, "Screens")
	cl.layer = 10
	_instance(cl, OUT + "hud.tscn", "Hud")
	_instance(cl, OUT + "nick_screen.tscn", "NickScreen")
	_instance(cl, OUT + "menu_screen.tscn", "MenuScreen")
	_instance(cl, OUT + "upgrades_screen.tscn", "UpgradesScreen")
	_instance(cl, OUT + "ranking_screen.tscn", "RankingScreen")
	_instance(cl, OUT + "buff_select_screen.tscn", "BuffSelectScreen")
	_instance(cl, OUT + "world_choice_screen.tscn", "WorldChoiceScreen")
	_instance(cl, OUT + "result_screen.tscn", "ResultScreen")
	_instance(cl, OUT + "pause_screen.tscn", "PauseScreen")
	var ps: PackedScene = PackedScene.new()
	ps.pack(scene_root)
	var err: int = ResourceSaver.save(ps, "res://scenes/main.tscn")
	if err != OK:
		printerr("save main falhou ", err)
	scene_root.free()
	scene_root = null
