class_name GameplayLits
extends RefCounted
## Literais que NAO estao em data/legacy/constants.json (numeros "soltos" do gameLoop).
## Unidades legadas; a conversao e feita por Units no ponto de uso.
## REBALANCEAMENTO FINAL (docs/balanceamento.md): estes valores JA divergem do index.html legado
## e o Godot e a fonte da verdade. Mudancas de balanceamento devem ser registradas em docs/balanceamento.md.

# --- urso (initGame / canMove / moveBear) ---
const BEAR_BASE_SPEED: float = 4.3        # px/frame legado, multiplicado por INITIAL_PACE
const BEAR_SIZE: float = 14.0             # px legados (raio de colisao)
const CAN_MOVE_HALF: float = 0.45         # canMove: caixa = size * 0.45
const WALL_SLIDE: float = 0.3             # moveBear: tentativa lateral a 30% do passo
const CAPTURE_MARGIN: float = 5.0         # px legados: captura = dist < bear.size + g.size - 5
const LANDING_SNAP: float = 6.0           # px legados: landingTarget alcancado se d < 6
const LANDING_STEP: float = 8.0           # px/frame legado: velocidade do deslize de aterrissagem

# --- pulo ---
const JUMP_CD_BASE: float = 8.0          # jumpCdMax sem atributo

# --- dificuldade por ciclo (biomeEffective) ---
const CYCLE_SPEED_ADD: float = 0.12
const CYCLE_RATE_SUB: float = 1.0
const MIN_GHOST_SPAWN_RATE: float = 6.0

# --- fantasmas ---
const GHOST_DIFF_CAP: float = 0.93        # teto de diff_mult()
const GHOST_CAP_BASE: int = 5             # teto de fantasmas: base + por fase, limitado por ciclo
const GHOST_CAP_PER_PHASE: int = 1
const GHOST_CAP_MAX: int = 14
const GHOST_CAP_PER_CYCLE: int = 2
const GHOST_CAP_ABS: int = 18             # teto absoluto
const GHOST_SPAWN_GRACE: float = 0.8      # s de graca (nao move/captura) em fantasmas criados na run
const JUMP_LAND_INVULN: float = 0.3
const INVISIBLE_END_INVULN: float = 0.6
const TELEPORT_INVULN: float = 0.5
const BURST_STUN: float = 1.5
const STOMP_RADIUS_CELLS: float = 2.5
const STOMP_STUN: float = 2.0
const STOMP_PUSH_RADIUS_CELLS: float = 1.6
const MAGNET_RADIUS_CELLS: float = 4.0
const MAGNET_PULL_CELLS_S: float = 6.0
const ORB_INTERVAL_POOL_FACTOR: float = 0.15
const ORB_INTERVAL_MIN: float = 4.0
const HONEY_PICKUP_PER_PHASE: int = 1
const HONEY_PICKUP_MAX: int = 15
const BIOME_CLEAR_HONEY: int = 10         # x fases concluidas
const BIOME_CLEAR_HONEY_MAX: int = 100
const ICE_MAX_SPEED_MULT: float = 1.65
const ICE_ACCEL_REF_SPEED: float = 3.6    # velocidade de referencia da aceleracao do gelo (accel = cfg.accel * mx/3.6)
const ERRANTE_MODE_BASE_MS: float = 4000.0
const ERRANTE_MODE_RANGE_MS: float = 4000.0
const WANDER_RETARGET_MS: float = 2000.0
const PUSH_CELLS: float = 1.6             # pushGhost: TILE * 1.6

# --- transicao de bioma ---
const GHOST_HIDE_SECONDS: float = 0.5
const TRANSITION_INVULN: float = 1.0
const TRANSITION_GHOST_MIN_CELLS: float = 10.0
const SHIELD_INVULN: float = 0.9

# --- mel (spawnHoney) ---
const HONEY_BEAR_MIN_CELLS: float = 3.0
const HONEY_SPACING_CELLS: float = 1.2

# --- controles ---
const JOY_DEADZONE: float = 0.18

# --- loop ---
const MAX_DT: float = 0.05

# --- buffs de mapa (applyMapBuff / triggerFixed / spawnCollectible; E4b) ---
const COLLECT_BEAR_MIN_CELLS: float = 3.0     # spawnCollectible: longe do urso (celulas)
const COLLECT_SPACING_CELLS: float = 1.2      # espacamento entre orbes (celulas)
const COLLECT_BORN_RANGE: float = 6.0         # born = rand * 6 (fase da animacao)
const BURST_RADIUS_CELLS: float = 3.5         # light_burst / light_bomb: alcance
const BURST_PUSH_CELLS: float = 3.0           # light_burst: empurrao
const BUFF_FX: Dictionary = {                 # duracoes (s) e multiplicadores do JS
	"speed_temp": {"dur": 4.0, "mult": 1.8},
	"freeze_all": {"dur": 4.0},
	"slow_time": {"dur": 4.0, "mult": 0.4},
	"spirit_trap": {"dur": 4.0},
	"fake_wall": {"dur": 4.0},
	"invisible": {"dur": 5.0},
	"decoy": {"dur": 6.0},
	"steal": {"dur": 4.0, "mult": 1.4},      # fantasma roubou o orbe
}
const MAX_SHIELD_CHARGES: int = 1
const NOTIF_LIFE: float = 1.7
const NOTIF_RISE: float = 0.5                 # px/frame legado
const PRE_RUN_OPTIONS: int = 5                # selecao pre-run: 5 opcoes
const PRE_RUN_PICKS: int = 3                  # ... escolhe 3
const WORLD_CHOICE_OPTIONS: int = 3

# --- mecanicas de bioma (E4b) ---
const MUSH_MIN_SPAWN_CELLS: float = 3.0       # cogumelos longe do spawn do urso
const MUSH_SQUASH_TIME: float = 0.15
const BAT_SPAWN_MARGIN: float = 20.0          # px legados fora do mapa
const BAT_CULL_MARGIN: float = 40.0
const BAT_ANGLE_SPREAD: float = 0.4           # +-0.4 rad
const BAT_FRAME_TIME: float = 0.18
const CASTLE_CLOSED_THRESHOLD: float = 0.4    # cl > 0.4 bloqueia
const SKY_WIND_BANDS: int = 3
const GEYSER_FIRE_AT: float = 0.6             # sin > 0.6 => fogo
const GEYSER_WARM_AT: float = 0.3             # sin > 0.3 => aquecendo
const GEYSER_INVULN: float = 0.4
const TRAIL_HIT_CELLS: float = 0.6
const VOID_FLASH_SWAP: float = 0.3
const VOID_FLASH_PORTAL: float = 0.25
const VOID_PHASE_KEEP: float = 0.2            # phaseTimer minimo durante 'phase'
const VOID_BLIND_GHOST_ALPHA: float = 0.15


## Constante numerica de data/legacy/constants.json pelo nome original (valor CRU).
static func c(const_name: String) -> float:
	return float(GameState.const_value(const_name, 0.0))
