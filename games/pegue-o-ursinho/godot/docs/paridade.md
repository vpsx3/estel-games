# Paridade JS -> GDScript (Pegue o Ursinho)

Fonte: `games/pegue-o-ursinho/index.html` (navegar por ancora de funcao). Unidades: ver `scripts/core/units.gd`.
Status: `ok` = portado + testado (nenhum `gancho` restante apos E10).

## E4a - nucleo de gameplay

| Sistema | Funcao JS de origem | Script GD | Teste | Status |
|---|---|---|---|---|
| Colisao por celula | `tileAt`, `canMove`, `freeCells` | `scripts/gameplay/grid_collision.gd` | test_gameplay_movement | ok |
| Movimento do urso | `moveBear`, `dirFromVec`, `bearSpeedMult` | `scripts/gameplay/bear_model.gd`, `run.gd` | test_gameplay_movement | ok |
| Urso: veneno/congelado/atributo velocidade | `moveBear`, `recalcPassives` | `bear_model.gd`, `run.gd` | test_gameplay_movement | ok |
| Mecanica de gelo (inercia) | `moveBearIce` | `run.gd::mech_move_bear`, `mechanics/mech_ice.gd` | test_gameplay_mech_a (ice_*) | ok |
| Fantasmas: criacao e 5 classes | `makeGhost`, `GHOST_TYPES` | `ghost_model.gd`, `ghost_system.gd` | test_gameplay_ghosts | ok |
| Spawn ponderado + minDist | `weightedRandom`, `spawnGhost`, `randomFreePosAway` | `ghost_system.gd`, `run.gd` | test_gameplay_ghosts | ok |
| Pace (INITIAL_PACE, GHOST_PHASE_SCALING, ciclo) | `getDiffMult`, `biomeEffective` | `ghost_system.gd`, `biome_cycle.gd` | test_gameplay_ghosts, _biomes | ok |
| Perseguicao (linha reta, decoy) | `moveGhosts` | `ghost_system.gd` | test_gameplay_ghosts | ok |
| Fantasma errante | `wanderMove`, `moveGhosts` | `ghost_system.gd` | test_gameplay_ghosts | ok |
| Fantasma venenoso (POISON_*) | `moveGhosts`, `updateEffects` | `ghost_system.gd`, `run.gd` | test_gameplay_ghosts | ok |
| Separacao entre fantasmas | `resolveGhostCollisions`, `clampGhost` | `ghost_system.gd` | test_gameplay_ghosts | ok |
| Flags de fantasma (frozen/trapped/boost) | `moveGhosts`, `updateEffects` | `ghost_model.gd`, `ghost_system.gd`, `run.gd` | test_gameplay_ghosts | ok |
| Ciclo de biomes (120s, aviso 10s) | `gameLoop`, `executeBiomeTransition` | `biome_cycle.gd`, `run.gd` | test_gameplay_biomes | ok |
| Anuncio do bioma / escolha de +1 buff | `resumeAfterChoice`, `openWorldChoice` | `run.gd::resume_after_choice`, `world_choice_handler` | test_gameplay_biomes | ok |
| Volta ao bioma 1 + escalada de ciclo | `executeBiomeTransition`, `biomeEffective` | `biome_cycle.gd`, `run.gd` | test_gameplay_biomes | ok |
| Troca de cena de fase | `loadBiomeMap`, `placeBearSafe` | `run.gd`, `game.gd::_load_level` | test_gameplay_camera_input | ok |
| Pulo (JUMP_DURATION, pulo duplo, jump_cd, jump_ext) | `tryJump`, `updateEffects`, `recalcPassives` | `jump_state.gd`, `run.gd` | test_gameplay_jump_honey | ok |
| Aterrissagem em parede | `resolveLandingInsideWall`, `updateEffects` | `grid_collision.gd`, `run.gd` | test_gameplay_jump_honey | ok |
| Mel: passivo, potes, limite, vida, raio, coleta | `updateHoney`, `spawnHoney`, `gameLoop` | `honey_system.gd` | test_gameplay_jump_honey | ok |
| Captura / game over / estatisticas | `gameLoop` (captura), `endGame` | `run.gd::step/end_game` | test_gameplay_capture | ok |
| Escudo / rebote na captura | `gameLoop`, `pushGhost` | `run.gd`, `ghost_system.gd` | test_gameplay_capture | ok |
| Camera (CAM_CONFIG, smoothing, bordas) | `resizeCanvas`, `cameraTarget`, `centerCameraOnBear` | `camera_rig.gd` | test_gameplay_camera_input | ok |
| Teclado (input map) | `keysDown`, `moveBear` | `input_reader.gd` | test_gameplay_camera_input | ok |
| Joystick virtual + botao de pulo (logica) | `joyStart/joyMove/joyEnd`, `btnJump` | `virtual_joystick.gd` (`PouJoystick`), `touch_controls.gd` | test_gameplay_camera_input | ok |
| Cena de jogo | `initGame`, `gameLoop` | `scenes/game.tscn`, `scripts/gameplay/game.gd`, `scenes/actors/*` | test_gameplay_camera_input | ok |
| Cena de jogo: orbes/mel/isca/notificacoes/mecanicas | `drawCollectibles`, `drawHoney`, `drawDecoy`, `drawNotifications`, `mechDraw*` | `scripts/gameplay/world_view.gd`, `game.gd` | test_gameplay_mech_factory (carga) + execucao com render | ok (arte: E8) |
| HUD, i18n completo, save de atributos na UI, ranking, telas | ver tabela E4c | - | - | ok (E4c) |

## E4b - buffs, loja e mecanicas de bioma

| Sistema | Funcao JS de origem | Script GD | Teste | Status |
|---|---|---|---|---|
| Dados dos 16 buffs (12 map + 4 fixed), pesos selW/mapW, raridade, FIXED_INTERVALS, SPRAY_* | `MAP_BUFFS`, `FIXED_INTERVALS`, `SPRAY_SLOW_*`, `rarColor` | `scripts/gameplay/buffs.gd` (`BuffSystem`) | test_gameplay_buffs::test_data_16_buffs | ok |
| Efeitos dos buffs de mapa (speed_temp, dash, freeze_all, ghost_slow, slow_time, teleport, swap, spirit_trap, fake_wall, invisible, light_burst, lightning, light_bomb, rebound, decoy, shield) | `applyMapBuff` | `buffs.gd::apply_map_buff`, `gameplay_lits.gd::BUFF_FX` | test_gameplay_buffs (timed_bear_buffs, teleport_swap, light_burst_and_bomb_radius, lightning_and_decoy..., shield_max_one_charge) | ok |
| Roubo do orbe pelo fantasma (+40% vel., 4s) | `applyMapBuff(id, ghost)`, `updateCollectibles` | `buffs.gd::update_collectibles/apply_map_buff` | test_gameplay_buffs::test_ghost_steals_orb | ok |
| Orbes no mapa: spawn ponderado por mapW, MAX_COLLECT, COLLECT_LIFE/R, expiracao | `spawnCollectible`, `updateCollectibles`, `weightedOne` | `buffs.gd::spawn_collectible/update_collectibles` | test_gameplay_buffs (spawn_rules, collect_by_bear_and_expiry), test_gameplay_buffs_flow::weighted_one_map_weights | ok |
| Buffs fixos por intervalo (spray, teia, raio, isca) | `activateFixed`, `triggerFixed`, loop `fixedTimers` | `buffs.gd::activate_fixed/trigger_fixed/update_fixed` | test_gameplay_buffs::test_fixed_buffs_intervals, test_run_loop_runs_buffs | ok |
| Escudo (max 1) e rebote absorvem captura | `gameLoop` (captura) | `run.gd::step`, `buffs.gd` | test_gameplay_buffs::test_shield_and_rebound_absorb_capture | ok |
| Selecao pre-run "3 de 5" (selW), startRun | `weightedPick`, `selectablePool`, `openSelection`, `togglePick`, `startRun` | `buffs.gd::open_selection/toggle_pick/start_run` | test_gameplay_buffs_flow (selection, toggle_pick, start_run_splits, selectable_pool) | ok (UI: E4c) |
| Escolha de +1 buff entre biomes e reroll (atributo) | `openWorldChoice`, `pickWorldBuff`, `worldReroll`, `resumeAfterChoice` | `buffs.gd::open_world_choice/pick_world_buff/world_reroll` | test_gameplay_buffs_flow (world_choice_flow, empty_pool, reroll_attribute, auto_choice) | ok (UI: E4c; `auto_choice` e placeholder) |
| Loja de atributos (ATTR_DEFS: custos, niveis, efeitos, compra debita mel, persiste) | `attrNextCost`, `attrEffectText`, `buyAttr`, `recalcPassives` | `scripts/gameplay/shop.gd` (`Shop`), `run.gd::recalc_passives`, `jump_state.gd` | test_gameplay_shop | ok (UI: E4c) |
| Mecanica: cogumelo-trampolim (bioma 1) | `mechInitMushroom`, `mechUpdateMushroom` | `scripts/gameplay/mechanics/mech_mushroom.gd` | test_gameplay_mech_a (mushroom_*) | ok |
| Mecanica: mare ciclica (bioma 2) | `mechInitTide`, `mechUpdateTide` | `mechanics/mech_tide.gd` | test_gameplay_mech_a (tide_*) | ok (so config) |
| Mecanica: piso de gelo / inercia (bioma 3) | `moveBearIce` | `mechanics/mech_ice.gd` | test_gameplay_mech_a (ice_*) | ok (so config) |
| Mecanica: vitoria-regia que afunda (bioma 4) | `mechInitLily`, `mechUpdateLily` | `mechanics/mech_lily.gd` | test_gameplay_mech_a (lily_*) | ok |
| Mecanica: morcegos que travam (bioma 5) | `mechInitBats`, `mechSpawnBat`, `mechUpdateBats` | `mechanics/mech_bats.gd` | test_gameplay_mech_a (bats_*) | ok |
| Mecanica: janelas que espreitam (bioma 6) | `mechInitWindows`, `mechUpdateWindows` | `mechanics/mech_windows.gd` | test_gameplay_mech_b (windows_*) | ok |
| Mecanica: grades + tapete (bioma 7) | `mechInitCastle`, `mechUpdateCastle`, `mechSpeedMult` | `mechanics/mech_castle.gd` | test_gameplay_mech_b (castle_*) | ok |
| Mecanica: plataformas moveis + vento (bioma 8) | `mechInitSky`, `mechUpdateSky`, `mechApplyDrift` | `mechanics/mech_sky.gd` | test_gameplay_mech_b (sky_*) | ok |
| Mecanica: geiseres + rastro de fogo (bioma 9) | `mechInitFire`, `mechUpdateFire`, `mechGeyserState` | `mechanics/mech_fire.gd` | test_gameplay_mech_b (fire_*) | ok |
| Mecanica: inversao de fases + portais (bioma 10) | `mechInitVoid`, `mechUpdateVoid`, `mechGhostAlpha` | `mechanics/mech_void.gd` | test_gameplay_mech_b (void_*) | ok (overlay "mapa respira" portado em draw_under) |
| Fabrica + fallback manual x procedural (Mecanicas vazio = JS) | `mechReset`, `mechBlocksBear`, `mechSpeedMult`, `mechApplyDrift` | `mechanics/mech_factory.gd`, `mechanics/mech_base.gd`, `scripts/gameplay/mech_marker.gd` | test_gameplay_mech_factory | ok |
| Cenas posicionaveis de mecanica | `MECH_SLOTS` | `scenes/mechanics/*.tscn` (+ `assets/_placeholder/mechanics/`) | test_gameplay_mech_factory::test_marker_scenes_load_and_defaults | ok |

### Mecanicas posicionaveis (`scenes/mechanics/`)

Arraste para `Mecanicas` da fase. Por subparte, se houver ao menos um marcador do `kind`, so valem os colocados a mao; sem nenhum, o jogo gera como o original (sorteio com a seed da run). Mare, gelo e inversao de fase (vazio) sao so configuracao do `BiomeConfig.mech`.

| Cena | kind | Efeito da posicao | Parametros por instancia (-1 = config) |
|---|---|---|---|
| `mushroom.tscn` | mushroom | cogumelo na celula | `dist` |
| `lilypad.tscn` | lilypad | vitoria-regia na celula | - |
| `bat_spawn.tscn` | bat_spawn | ponto de entrada dos morcegos (posicao livre) | - |
| `window.tscn` | window | janela em celula de PAREDE | `radius_cells`, `telegraph`, `cooldown` |
| `gate.tscn` | gate | grade na celula | `phase` |
| `carpet.tscn` | carpet | tapete a partir da celula, para a direita | `length_cells` |
| `platform.tscn` | platform | plataforma movel | `axis`, `range_cells`, `phase` |
| `wind.tscn` | wind | corrente de ar a partir da celula | `wind_dir`, `length_cells` |
| `geyser.tscn` | geyser | geiser na celula | `phase` |
| `portal.tscn` | portal | portal na celula | - |

## E4c - i18n, save, ranking e telas

| Sistema | Funcao JS de origem | Script GD | Teste | Status |
|---|---|---|---|---|
| i18n PT/EN, `estel_lang`, deteccao do navegador, fallback PT, troca em runtime | `T`, `setLang`, `initLang`, `buffName/Desc`, `mapFxText`, `biomeName`, `rarLabel` | `autoload/i18n.gd`, `i18n/ui_extra.json`, `scripts/ui/ui_text.gd`, `scripts/ui/lang_toggle.gd` | test_ui_i18n | ok (texto sem emoji via `strip_emoji`) |
| Save `{honey, attrs, skins}` (`estel_pou_save` / `user://save.json`), campos desconhecidos preservados | `loadSave`, `persistSave`, `DEFAULT_SAVE` | `autoload/save.gd` | test_ui_save_api | ok |
| Ranking: sessao ao iniciar a run, listar, enviar score (falha silenciosa) | `startSession`, `loadScores`, `saveScore` | `autoload/api_client.gd`, `game.gd::begin` | test_ui_save_api, test_ui_screens | ok (HTTPRequest; mock via `transport`) |
| Tela de apelido (trim, max 16) | `btnPlay` handler, `#nickInput` | `scripts/ui/nick_screen.gd`, `scenes/ui/nick_screen.tscn` | test_ui_screens | ok |
| Menu inicial | `screenMenu`, `refreshMenu` | `menu_screen.gd` | test_ui_screens | ok |
| Loja de atributos (UI) | `renderUpgrades`, `buyAttr` | `upgrades_screen.gd`, `upgrade_card.gd` | test_ui_screens | ok |
| Selecao 3 de 5 | `openSelection`, `togglePick`, `updateStartBtn`, `startRun` | `buff_select_screen.gd`, `buff_card.gd`, `game.gd::prepare/begin` | test_ui_screens | ok |
| Escolha +1 buff com reroll | `renderWorldChoiceCards`, `openWorldChoice`, `worldReroll` | `world_choice_screen.gd` (`buffs.auto_choice = false`) | test_ui_screens | ok |
| HUD (tempo, mel, fantasmas, bioma, efeitos com barra, fixos, aviso, anuncio) | `renderEffectsHud`, `activeEffects`, `renderPassiveHud`, `drawBiomeWarning`, `drawBiomeAnnounce` | `hud.gd`, `fx_chip.gd`, `passive_chip.gd` | test_ui_screens | ok |
| Game over + envio do score | `endGame` | `result_screen.gd`, `main_flow.gd::_on_run_ended` | test_ui_screens | ok |
| Ranking (lista, destaque da partida) | `renderRanking` | `ranking_screen.gd`, `ranking_row.gd` | test_ui_screens | ok |
| Pausa (Esc / botao) | - (nao existe no HTML) | `pause_screen.gd`, `main_flow.gd`, `game.gd::set_paused` | test_ui_screens | ok (extensao) |
| Fluxo completo / main_scene | `showScreen`, `startGame` | `scenes/main.tscn`, `main_flow.gd` | test_ui_screens::test_full_flow | ok |
| Controles touch so em `Device.is_touch` | `IS_TOUCH` | `touch_controls.gd` (E4a) | test_ui_screens | ok |
| Tela `screenHowto` | `screenHowto` | - | - | nao portada (inalcancavel no HTML) |

## E10 - correcoes do QA (guardas de regressao)

| Sistema | Funcao JS de origem | Script GD | Teste | Status |
|---|---|---|---|---|
| Empurrao de captura TILE*1.6 (PUSH_CELLS) | `pushGhost` | `ghost_system.gd::push_ghost` | test_parity_guards::test_push_ghost_moves_exact_cells | ok |
| Momento da erupcao do geiser (GEYSER_FIRE_AT 0.6) | `mechGeyserState` | `mechanics/mech_fire.gd::geyser_state/fire_progress` | test_parity_guards::test_geyser_eruption_moment | ok |
| Distancia do portal do vazio (>= 8 celulas) | `mechUpdateVoid` | `mechanics/mech_void.gd::update` | test_parity_guards::test_void_portal_distance | ok |
| Distancia minima do teleporte (6 celulas) | `applyMapBuff` (teleport) | `buffs.gd::apply_map_buff` | test_parity_guards::test_teleport_min_distance | ok |
| VFX certo por evento/estado (jump, freeze_all, teleport, light_bomb, honey_pickup, biome_transition, shield, shield_break, poisoned, caught) | - (extensao PixelLab) | `scripts/vfx/vfx_director.gd` | test_parity_guards::test_vfx_director_right_effect_per_event | ok |
| Icones de bioma do HUD (`biome_%02d` -> assets/ui/icons) | - (emoji no HTML) | `scripts/ui/hud.gd`, `ui_icons.gd` | test_parity_guards::test_biome_icon_keys_resolve_to_files | ok (result_screen nao usa icone de bioma) |
