extends Node
## Stub de audio. TODO: AudioStreamPlayers/bus quando houver assets aprovados.

var muted: bool = false


func play_sfx(_sfx_name: String) -> void:
	pass


func play_music(_track: String) -> void:
	pass


func stop_music() -> void:
	pass


func set_muted(value: bool) -> void:
	muted = value
