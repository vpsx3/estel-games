class_name RankingRow
extends PanelContainer
## Linha do ranking. Variacoes de tema: RankRowTop (1o a 3o) e RankRowMe (a partida recem-terminada).

@onready var medal: TextureRect = %Medal
@onready var rank_label: Label = %RankLabel
@onready var nick_label: Label = %NickLabel
@onready var new_badge: Label = %NewBadge
@onready var time_label: Label = %TimeLabel
@onready var ghosts_label: Label = %GhostsLabel


## s = {nick, seconds, ghosts}. ghosts nao finito => 0 (Number.isFinite).
func setup(index: int, s: Dictionary, is_me: bool) -> void:
	rank_label.text = "%dº" % (index + 1)
	nick_label.text = str(s.get("nick", ""))
	time_label.text = UiText.format_time(float(s.get("seconds", 0)))
	var g: float = float(s.get("ghosts", 0))
	ghosts_label.text = str(0 if (is_nan(g) or is_inf(g)) else floori(g))
	new_badge.visible = is_me
	new_badge.text = I18n.t("badge_new")
	medal.visible = index < 3
	if index < 3:
		var key: String = "medal_%d" % (index + 1)
		UiIcons.apply(medal, key, UiIcons.color_for(key), str(index + 1))
	if is_me:
		theme_type_variation = &"RankRowMe"
	elif index < 3:
		theme_type_variation = &"RankRowTop"
