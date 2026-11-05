extends Node
## Barramento global de sinais. O gameplay emite/escuta aqui para desacoplar sistemas.

signal game_started()
signal game_over(stats: Dictionary)  # {seconds, ghosts, biome_reached, honey}
signal pause_changed(paused: bool)

signal bear_caught()
signal bear_jumped()
signal ghost_spawned(ghost_type: String)
signal ghost_eliminated(ghost_type: String)

signal biome_changed(biome_index: int)       # 0-based
signal biome_warning(seconds_left: float)
signal biome_announce(biome_index: int)

signal honey_collected(amount: int)
signal honey_changed(total: int)
signal buff_selected(buff_id: String)
signal buff_activated(buff_id: String)
signal attr_purchased(attr_id: String, level: int)

signal language_changed(lang: String)
