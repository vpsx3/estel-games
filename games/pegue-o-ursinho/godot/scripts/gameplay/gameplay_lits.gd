class_name GameplayLits
extends RefCounted
## Literais do JS que NAO estao em data/legacy/constants.json (numeros "soltos" no gameLoop).
## Mantidos EXATAMENTE como no index.html (unidades legadas); a conversao e feita por Units
## no ponto de uso. Registrados em docs/auditoria.md. NAO alterar valores de balanceamento.

# --- urso (initGame / canMove / moveBear) ---
const BEAR_BASE_SPEED: float = 3.3        # px/frame legado, multiplicado por INITIAL_PACE
const BEAR_SIZE: float = 14.0             # px legados (raio de colisao)
const CAN_MOVE_HALF: float = 0.45         # canMove: caixa = size * 0.45
const WALL_SLIDE: float = 0.3             # moveBear: tentativa lateral a 30% do passo
const CAPTURE_MARGIN: float = 5.0         # px legados: captura = dist < bear.size + g.size - 5
const LANDING_SNAP: float = 6.0           # px legados: landingTarget alcancado se d < 6
const LANDING_STEP: float = 8.0           # px/frame legado: velocidade do deslize de aterrissagem

# --- pulo ---
const JUMP_CD_BASE: float = 10.0          # jumpCdMax sem atributo

# --- dificuldade por ciclo (biomeEffective) ---
const CYCLE_SPEED_ADD: float = 0.10
const CYCLE_RATE_SUB: float = 2.0
const MIN_GHOST_SPAWN_RATE: float = 5.0

# --- fantasmas ---
const ERRANTE_MODE_BASE_MS: float = 4000.0
const ERRANTE_MODE_RANGE_MS: float = 4000.0
const WANDER_RETARGET_MS: float = 2000.0
const PUSH_CELLS: float = 1.6             # pushGhost: TILE * 1.6

# --- transicao de bioma ---
const GHOST_HIDE_SECONDS: float = 0.5
const TRANSITION_INVULN: float = 1.0
const TRANSITION_GHOST_MIN_CELLS: float = 10.0
const SHIELD_INVULN: float = 0.9
const REBOUND_INVULN: float = 1.1

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
const TELEPORT_MIN_CELLS: float = 6.0         # teleport: longe do fantasma mais proximo
const BURST_RADIUS_CELLS: float = 3.5         # light_burst / light_bomb: alcance
const BURST_PUSH_CELLS: float = 2.2           # light_burst: empurrao
const BUFF_FX: Dictionary = {                 # duracoes (s) e multiplicadores do JS
	"speed_temp": {"dur": 4.0, "mult": 1.8},
	"dash": {"dur": 0.8, "mult": 2.4},
	"freeze_all": {"dur": 4.0},
	"ghost_slow": {"dur": 5.0, "mult": 0.5},
	"slow_time": {"dur": 4.0, "mult": 0.4},
	"spirit_trap": {"dur": 5.0},
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
const VOID_PORTAL_AWAY_CELLS: float = 8.0
const VOID_BLIND_GHOST_ALPHA: float = 0.15


## Constante numerica de data/legacy/constants.json pelo nome original (valor CRU).
static func c(const_name: String) -> float:
	return float(GameState.const_value(const_name, 0.0))
