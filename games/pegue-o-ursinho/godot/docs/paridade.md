# Paridade JS -> GDScript (Pegue o Ursinho)

Fonte: `games/pegue-o-ursinho/index.html` (navegar por ancora de funcao). Unidades: ver `scripts/core/units.gd`.
Status: `ok` = portado + testado; `gancho` = so o ponto de extensao existe (parte E4b/E4c).

## E4a - nucleo de gameplay

| Sistema | Funcao JS de origem | Script GD | Teste | Status |
|---|---|---|---|---|
| Colisao por celula | `tileAt`, `canMove`, `freeCells` | `scripts/gameplay/grid_collision.gd` | test_gameplay_movement | ok |
| Movimento do urso | `moveBear`, `dirFromVec`, `bearSpeedMult` | `scripts/gameplay/bear_model.gd`, `run.gd` | test_gameplay_movement | ok |
| Urso: veneno/congelado/atributo velocidade | `moveBear`, `recalcPassives` | `bear_model.gd`, `run.gd` | test_gameplay_movement | ok |
| Mecanica de gelo (inercia) | `moveBearIce` | `run.gd::mech_move_bear` | - | gancho (E4b) |
| Fantasmas: criacao e 5 classes | `makeGhost`, `GHOST_TYPES` | `ghost_model.gd`, `ghost_system.gd` | test_gameplay_ghosts | ok |
| Spawn ponderado + minDist | `weightedRandom`, `spawnGhost`, `randomFreePosAway` | `ghost_system.gd`, `run.gd` | test_gameplay_ghosts | ok |
| Pace (INITIAL_PACE, GHOST_PHASE_SCALING, ciclo) | `getDiffMult`, `biomeEffective` | `ghost_system.gd`, `biome_cycle.gd` | test_gameplay_ghosts, _biomes | ok |
| Perseguicao (linha reta, decoy) | `moveGhosts` | `ghost_system.gd` | test_gameplay_ghosts | ok |
| Fantasma errante | `wanderMove`, `moveGhosts` | `ghost_system.gd` | test_gameplay_ghosts | ok |
| Fantasma venenoso (POISON_*) | `moveGhosts`, `updateEffects` | `ghost_system.gd`, `run.gd` | test_gameplay_ghosts | ok |
| Separacao entre fantasmas | `resolveGhostCollisions`, `clampGhost` | `ghost_system.gd` | test_gameplay_ghosts | ok |
| Flags de fantasma (frozen/trapped/boost) | `moveGhosts`, `updateEffects` | `ghost_model.gd`, `ghost_system.gd`, `run.gd` | test_gameplay_ghosts | ok (efeitos: gancho E4b) |
| Ciclo de biomes (120s, aviso 10s) | `gameLoop`, `executeBiomeTransition` | `biome_cycle.gd`, `run.gd` | test_gameplay_biomes | ok |
| Anuncio do bioma / escolha de +1 buff | `resumeAfterChoice`, `openWorldChoice` | `run.gd::resume_after_choice`, `world_choice_handler` | test_gameplay_biomes | ok (UI/escolha: gancho E4b/E4c) |
| Volta ao bioma 1 + escalada de ciclo | `executeBiomeTransition`, `biomeEffective` | `biome_cycle.gd`, `run.gd` | test_gameplay_biomes | ok |
| Troca de cena de fase | `loadBiomeMap`, `placeBearSafe` | `run.gd`, `game.gd::_load_level` | test_gameplay_camera_input | ok |
| Pulo (JUMP_DURATION, pulo duplo, jump_cd, jump_ext) | `tryJump`, `updateEffects`, `recalcPassives` | `jump_state.gd`, `run.gd` | test_gameplay_jump_honey | ok |
| Aterrissagem em parede | `resolveLandingInsideWall`, `updateEffects` | `grid_collision.gd`, `run.gd` | test_gameplay_jump_honey | ok |
| Mel: passivo, potes, limite, vida, raio, coleta | `updateHoney`, `spawnHoney`, `gameLoop` | `honey_system.gd` | test_gameplay_jump_honey | ok |
| Captura / game over / estatisticas | `gameLoop` (captura), `endGame` | `run.gd::step/end_game` | test_gameplay_capture | ok (tela/ranking: E4c) |
| Escudo / rebote na captura | `gameLoop`, `pushGhost` | `run.gd`, `ghost_system.gd` | test_gameplay_capture | ok (concessao do buff: E4b) |
| Camera (CAM_CONFIG, smoothing, bordas) | `resizeCanvas`, `cameraTarget`, `centerCameraOnBear` | `camera_rig.gd` | test_gameplay_camera_input | ok |
| Teclado (input map) | `keysDown`, `moveBear` | `input_reader.gd` | test_gameplay_camera_input | ok |
| Joystick virtual + botao de pulo (logica) | `joyStart/joyMove/joyEnd`, `btnJump` | `virtual_joystick.gd` (`PouJoystick`), `touch_controls.gd` | test_gameplay_camera_input | ok (arte: E4c) |
| Cena de jogo (placeholder) | `initGame`, `gameLoop` | `scenes/game.tscn`, `scripts/gameplay/game.gd`, `scenes/actors/*` | test_gameplay_camera_input | ok |
| Buffs de mapa/fixos, loja, mecanicas de bioma, HUD, i18n, save de atributos, ranking | - | - | - | pendente (E4b/E4c) |
