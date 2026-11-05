class_name BiomeCycle
extends RefCounted
## Estado do ciclo de biomes. Porta currentBiome/cycleCount/phasesCleared/biomeStartTime/
## biomePhase/shakeFrames/ghostHideTimer/biomeAnnounceTimer + biomeEffective + o timer do gameLoop.
## Fases: "playing" | "warning" | "transitioning" | "choosing" (pausa real durante a escolha de buff).
## Todos os tempos em segundos (BIOME_DURATION, BIOME_WARNING_TIME, BIOME_ANNOUNCE_DURATION).

var current_biome: int = 0
var cycle_count: int = 0
var phases_cleared: int = 0
var start_time: float = 0.0
var phase: String = "playing"
var shake_frames: int = 0
var ghost_hide_timer: float = 0.0
var announce_timer: float = 0.0


func reset() -> void:
	current_biome = 0
	cycle_count = 0
	phases_cleared = 0
	start_time = 0.0
	phase = "playing"
	shake_frames = 0
	ghost_hide_timer = 0.0
	announce_timer = 0.0


## biomeEffective(b): velocidade + 0.10/ciclo; taxa de spawn - 2s/ciclo (minimo 5s).
static func effective_speed(base_ghost_speed: float, cycle: int) -> float:
	return base_ghost_speed + cycle * GameplayLits.CYCLE_SPEED_ADD


static func effective_spawn_rate(base_rate: float, cycle: int) -> float:
	return maxf(GameplayLits.MIN_GHOST_SPAWN_RATE, base_rate - cycle * GameplayLits.CYCLE_RATE_SUB)


func biome_elapsed(elapsed: float) -> float:
	return elapsed - start_time


func remaining(elapsed: float) -> float:
	return maxf(0.0, GameplayLits.c("BIOME_DURATION") - biome_elapsed(elapsed))


## Trecho do gameLoop: playing->warning aos (DURATION - WARNING)s; warning->transicao aos DURATION s.
## Retorna true quando a transicao deve ser executada AGORA (ambos checks no mesmo frame, como no JS).
func tick(elapsed: float) -> bool:
	var be: float = biome_elapsed(elapsed)
	if phase == "playing" and be >= GameplayLits.c("BIOME_DURATION") - GameplayLits.c("BIOME_WARNING_TIME"):
		phase = "warning"
		Events.biome_warning.emit(remaining(elapsed))
	return phase == "warning" and be >= GameplayLits.c("BIOME_DURATION")


## Avanca o indice (executeBiomeTransition): +1 fase concluida; ao voltar ao 1 sobe o ciclo.
func advance() -> void:
	phase = "transitioning"
	shake_frames = 3
	ghost_hide_timer = GameplayLits.GHOST_HIDE_SECONDS
	current_biome = (current_biome + 1) % int(GameplayLits.c("TOTAL_BIOMES"))
	phases_cleared += 1
	if current_biome == 0:
		cycle_count += 1


func update_timers(dt: float) -> void:
	if ghost_hide_timer > 0.0:
		ghost_hide_timer = maxf(0.0, ghost_hide_timer - dt)
	if announce_timer > 0.0:
		announce_timer = maxf(0.0, announce_timer - dt)
