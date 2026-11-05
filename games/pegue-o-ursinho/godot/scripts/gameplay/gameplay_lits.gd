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


## Constante numerica de data/legacy/constants.json pelo nome original (valor CRU).
static func c(const_name: String) -> float:
	return float(GameState.const_value(const_name, 0.0))
