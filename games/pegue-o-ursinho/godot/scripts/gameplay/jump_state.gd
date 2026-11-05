class_name JumpState
extends RefCounted
## Pulo. Porta jumpCd/jumpActive/jumpTimer/jumpCdMax/jumpDuration/jumpsLeft, tryJump e o trecho do
## pulo em updateEffects. Atributos (loja) entram por recalc():
##   jump_cd  -> cdMax = 10 * (1 - values[lv-1])      (10 = JUMP_CD_BASE do JS)
##   jump_ext -> duration = JUMP_DURATION + values[lv-1]
##   double_jump -> max_jumps() = 2

var cd: float = 0.0
var active: bool = false
var timer: float = 0.0
var cd_max: float = GameplayLits.JUMP_CD_BASE
var duration: float = 0.0
var jumps_left: int = 0
var double_jump: bool = false


func _init() -> void:
	duration = GameplayLits.c("JUMP_DURATION")


func reset() -> void:
	cd = 0.0
	active = false
	timer = 0.0
	jumps_left = 0
	recalc({})


## attr_levels: {attr_id: nivel}. Equivale ao trecho de jump de recalcPassives().
func recalc(attr_levels: Dictionary) -> void:
	var defs: Dictionary = GameState.attrs["defs"] as Dictionary
	var lv_cd: int = int(attr_levels.get("jump_cd", 0))
	var lv_ext: int = int(attr_levels.get("jump_ext", 0))
	cd_max = GameplayLits.JUMP_CD_BASE
	if lv_cd > 0:
		cd_max = GameplayLits.JUMP_CD_BASE * (1.0 - float(((defs["jump_cd"] as Dictionary)["values"] as Array)[lv_cd - 1]))
	duration = GameplayLits.c("JUMP_DURATION")
	if lv_ext > 0:
		duration += float(((defs["jump_ext"] as Dictionary)["values"] as Array)[lv_ext - 1])
	double_jump = int(attr_levels.get("double_jump", 0)) > 0


func max_jumps() -> int:
	return 2 if double_jump else 1


## tryJump(): "started" | "double" | "" (ignorado).
func try_jump(bear_frozen: bool, choosing: bool) -> String:
	if bear_frozen or choosing:
		return ""
	if not active:
		if cd > 0.0:
			return ""
		jumps_left = max_jumps() - 1
		active = true
		timer = duration
		return "started"
	elif jumps_left > 0:
		jumps_left -= 1
		timer = duration   # re-impulso no ar renova a duracao
		return "double"
	return ""


## Trecho do pulo de updateEffects(dt). Retorna true no frame em que pousa.
func update(dt: float) -> bool:
	if cd > 0.0:
		cd -= dt
	if active:
		timer -= dt
		if timer <= 0.0:
			active = false
			jumps_left = 0
			cd = cd_max
			return true
	return false
