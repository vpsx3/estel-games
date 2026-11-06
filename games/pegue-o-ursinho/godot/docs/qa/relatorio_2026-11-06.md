# Relatorio de QA independente - Pegue o Ursinho (Godot) - 06/11/2026

Escopo: HANDOFF §10 (criterios de aceite) e §11 (intocaveis). Commit avaliado: `0888ffe` (HEAD de main). QA somente leitura/execucao; unico artefato criado: este relatorio e `evidencias/`.
Godot 4.7.2 headless, Chrome 156 headless via CDP, Node 24, Python 3.13.

## 1. Veredito

Nenhuma falha bloqueante. Dos 12 criterios do §10: 11 aprovados e 1 aprovado com ressalvas (arte). Ha 1 falha de severidade MEDIA (icones de bioma do HUD caem em placeholder) e varias baixas (secao 3).

## 2. Tabela de criterios

| # | Criterio (§10) | Resultado | Evidencia |
|---|---|---|---|
| 1a | Projeto abre sem erros (`--import`) | APROVADO | `--import` exit 0, 0 ocorrencias de ERROR/WARNING em `evidencias/import.log` |
| 1b | `tests/run_all.gd` passa headless | APROVADO | `--- 139 passed, 0 failed ---` (`evidencias/run_all.log`). Ruido no encerramento do modo --script (RIDs/ObjectDB leaked at exit): nao e falha |
| 1c | Validador de fases verde | APROVADO | 10x `OK ... (0 aviso(s))`, `0 fase(s) com erro` (`evidencias/validate_levels.log`) |
| 2a | 10 fases como cenas | APROVADO | `levels/biome_01..10_*.tscn` + `_template_biome.tscn`; hierarquia Visual/DetalhePiso/Logica/Decor/Mecanicas/Spawns |
| 2b | `Logica` == `BIOME_MAPS` | APROVADO | Extrai `BIOME_MAPS` do `index.html` com Node (vm) e comparei celula a celula com as 10 cenas lidas pelo Godot (tile atlas 1 = parede, vazio = piso): 0 celulas diferentes nos 10 mapas 30x18 (`evidencias/logica_vs_biome_maps.txt`). Tambem: ghost_speed, ghost_spawn_rate, spawns do urso/fantasma e `BIOME_MECH` das 10 `BiomeConfig` batem com `BIOMES`/`BIOME_MECH` do HTML (so a ordem das chaves do Dictionary difere; valores iguais) (`evidencias/biome_cfg_vs_html.txt`) |
| 2c | `docs/como-editar-fases.md` existe e e coerente | APROVADO | Botoes do doc (Repintar visual, Espalhar detalhes, Validar fase) = `@export_tool_button` em `scripts/level/level_root.gd:29-31`; campos config, edicao_manual, detail_density, detail_seed existem; nos SpawnUrso/SpawnFantasma/Mecanicas existem nas cenas; 10 cenas de marcador em `scenes/mechanics/`; comando do validador funciona. Ressalva: arrastar/repintar no editor GUI nao pode ser exercitado headless (so por test_painter_* e test_set_wall_runtime) |
| 3 | Paridade numerica (units.gd vs legado) | APROVADO | 22 constantes + CAM_CONFIG + FIXED_INTERVALS + GHOST_TYPES + 16 MAP_BUFFS (id/rar/selW/mapW/type) + 5 ATTR_DEFS (custos, niveis, valores) extraidos do HTML por script proprio = `data/legacy/*.json`: 0 divergencias (`evidencias/legacy_json_vs_html.txt`). Uso no GDScript conferido (>= 40 numeros, secao 4). As 121 ancoras JS citadas em `paridade.md` existem no HTML (`evidencias/anchors_missing.txt`: so 4 nomes compostos/curinga, todos existem separados) |
| 4 | 5 fantasmas, 16 buffs, mel, loja, pulo/duplo, ciclo 10 biomes, 10 mecanicas | APROVADO | Existem e tem teste (secao 5). Teste de mutacao (F4): 8 de 12 literais mutados foram pegos pela suite |
| 5a | Camera conforme CAM_CONFIG + joystick/pulo touch | APROVADO | Mobile 390x844: 9 tiles de largura; desktop 1366x768: 18 tiles. Joystick moveu o urso; botao de pulo mostra anel de recarga apos toque (`m_06_joy.png`, `m_08_jump.png`); desktop nao mostra controles (`d_08_play.png`) |
| 5b | PT/EN via `estel_lang` | APROVADO | Clique EN grava localStorage `estel_lang="en"`, PT grava `"pt"`; texto muda (`d_04_en.png`) |
| 5c | Save via `estel_pou_save` | APROVADO | Apos game over: `{"attrs":{"double_jump":0,"jump_cd":0,"jump_ext":0,"reroll":0,"speed_base":0},"honey":13,"skins":{"equipped":"default","owned":["default"]}}`; apos recarregar a pagina o menu mostra mel 13 (`m_03_menu.png`) |
| 5d | Ranking com mesmo GAME_ID e payload identico | APROVADO | Interceptado via CDP: POST /api/session {"game":"pegue-o-ursinho"} ao iniciar a run; GET /api/scores?game=pegue-o-ursinho; POST /api/scores {"biomeReached":"Floresta Encantada","game":"pegue-o-ursinho","ghosts":1,"nick":"QAtester","seconds":13,"token":null}. Campo a campo = fetch do HTML (game, nick, seconds, ghosts, biomeReached, token; token null sem sessao; biomeReached = nome PT). Unica diferenca: ordem das chaves (Godot ordena alfabeticamente); `api/scores.js` le por nome (body.game, body.nick...), irrelevante |
| 6a | Arte: tudo PixelLab aprovado ou derivado documentado | APROVADO COM RESSALVAS | 0 PNG do projeto e byte-identico a PNG do jogo legado (`evidencias/art_hash_check.txt`). 177 PNG fora de art_source; todos rastreados a destinos dos ledgers (`ledger*.csv`, `ledger_ui.csv`) exceto 17 derivados (botoes, `_x2`, `_dark`, chip_dark, jump_*, timebar_fill, atlas do morcego, swatch), a maioria explicada por observacoes de ledger, `assemble.py` e `build_spriteframes.py`; lacunas em F3. Linhas `reprovado`/`rejeitado` dos ledgers nao foram copiadas para `assets/` |
| 6b | Nenhum asset legado/placeholder restante | REPROVADO (parcial) | Placeholder real: icones de bioma do HUD (F1). `icon.svg` desenhado a mao (F2). `themes/_placeholder_theme.tres` existe mas nao e referenciado em runtime |
| 6c | Nenhum emoji na UI | APROVADO | Varredura de .gd/.tscn/.tres/.json fora de `data/legacy`: emoji so em `data/biomes/biome_XX.tres` (campo icon, nunca exibido: nenhum acesso a icon de bioma em scripts/ ou autoload/) e em 2 asserts de teste. `I18n.t()` passa por `UiText.strip_emoji`; screenshots sem emoji (`evidencias/emoji_scan.txt`) |
| 7 | VFX dos 16 buffs + eventos | APROVADO | `scripts/vfx/vfx_director.gd` cobre speed_temp, dash, freeze_all, ghost_slow, slow_time, teleport/swap, spirit_trap, fake_wall, invisible, light_burst, lightning, light_bomb, rebound, decoy, shield, alem de poison, shield_break, jump, honey_pickup, ghost_eliminated, game_over, biome_changed/warning; 28 pastas em `assets/vfx/`. `test_vfx_director_runs_all_buffs` passa (fraco: so conta VfxPlayer > 0, F4) |
| 8a | Build web LOCAL (CSP emulada) | APROVADO | Fluxo completo ok (apelido, menu, selecao 3 de 5, jogo com WASD/espaco, game over, ranking). Console: 0 violacoes de CSP, 0 erros de wasm/JS. Unicos "errors" sao os 501/404 esperados da API inexistente no servidor local; o jogo seguiu sem travar e o ranking mostra "Nenhum recorde ainda". Viewports 1366x768 e 390x844 (touch): nada cortado, UI centrada (`screenshots/d_*.png`, `m_*.png`) |
| 8b | Build web PRODUCAO | APROVADO | curl -I em index.html, index.js, index.wasm: exatamente 1 Content-Security-Policy por resposta, com 'wasm-unsafe-eval' e sem 'unsafe-eval' (`evidencias/prod_headers.txt`); md5 de html/wasm/pck em producao = arquivos do repo; carrega, console sem erro, tela inicial e Ranking (GET) abrem. Nenhuma partida iniciada, nenhum POST em producao. Observacao: GET /api/scores em producao responde HTTP 500 ({"error":"Erro ao buscar scores"}); o cliente falha em silencio ("Nenhum recorde ainda"). E problema de backend/Redis, independente deste projeto (`api/` intocada; afeta o jogo legado igualmente) |
| 9 | Legado intacto | APROVADO | `git diff b375ac4..HEAD` vazio em `games/pegue-o-ursinho/index.html`, `assets/`, `tools/`, `api/` (`evidencias/legacy_intact.txt`). `vercel.json`: somente adicao da regra escopada /games/pegue-o-ursinho/web/(.*); regra global anterior identica. Demais mudancas fora de godot/web: `.claude/agents/*`, `.vercelignore` |
| 10 | Commits escopados + status.md | APROVADO COM RESSALVAS | 28 commits, todos conventional (feat/fix/docs/chore com escopo ursinho-*), todos dentro de `games/pegue-o-ursinho/godot|web`, `.claude/agents`, `.vercelignore`, `vercel.json`; nenhum .godot/, __pycache__, .bak ou .log rastreado; maior arquivo 39,5 MB (index.wasm). `status.md` tem geracoes gastas (~335, saldo 1665) mas esta desatualizado (F5). Commit `8923739 feat(ursinho-ui)` tambem alterou `project.godot`, `game.gd` e `touch_controls.gd` (escopo um pouco maior que o titulo) |

## 3. Falhas e observacoes com reproducao

### F1 - MEDIA - Icones de bioma do HUD ficam em placeholder (9 de 10 biomas)
- `scripts/ui/hud.gd:38,107-108` chama `UiIcons.apply(..., "biome_%d" % (b+1), ...)`; `UiIcons.apply` procura `res://assets/ui/icons/biome_<n>.png`, mas os arquivos se chamam `biome_01.png` ... `biome_10.png`. So `biome_10` casa por acaso. Os demais caem no quadrado colorido com inicial (placeholder).
- Reproducao: rodar com `--script` um script que chame `ResourceLoader.exists("res://assets/ui/icons/biome_1.png")` (ou `ls assets/ui/icons | grep biome`). Saida: `MISSING biome_1 ... biome_9` (`evidencias/ui_icon_keys.txt`).
- Impacto visual nao confirmado nas screenshots: o icone nao aparece ao lado de "Mundo 1/10" no HUD; aparece no banner de troca de bioma (exige 120 s de jogo, nao percorrido). Correcao sugerida: renomear para `biome_1..9.png` ou formatar a chave com `%02d`.
- Viola: nenhum placeholder restante (§10 arte).

### F2 - BAIXA - `icon.svg` do projeto e vetor desenhado a mao
`project.godot` `config/icon="res://icon.svg"` (urso feito de circulos SVG), origem do favicon do build web. Nao consta nos ledgers PixelLab. Trocar por recorte do urso aprovado.

### F3 - BAIXA - Lacunas de ledger para derivados
`assets/ui/panels/chip_dark.png` e `button_*_x2.png` nao tem linha propria em `ledger_ui.csv` (derivacao so em `art_source/pixellab/ui/_raw/assemble.py`). Os 65 PNG sem copia identica em `art_source` (atlas de spritesheet, tiles) sao gerados por `build_spriteframes.py`; recomenda-se uma linha "derivado de" por grupo (`evidencias/art_ledger_match.txt`, `art_hash_check.txt`).

### F4 - BAIXA - Buracos na suite (teste de mutacao)
Mutei literais numa COPIA do projeto (scratchpad) e rodei `run_all.gd`. A suite NAO detectou: PUSH_CELLS 1.6 para 1.5 (rebote de captura), GEYSER_FIRE_AT 0.6 para 0.5, VOID_PORTAL_AWAY_CELLS 8 para 5, TELEPORT_MIN_CELLS 6 para 5 (os valores atuais estao CERTOS contra o HTML; o risco e regressao futura). Detectou: speed_temp mult, CYCLE_RATE_SUB, BURST_RADIUS, CAPTURE_MARGIN, MAX_SHIELD_CHARGES, TILE_SCALE, JUMP_CD_BASE, decoy dur, SHIELD_INVULN. Alem disso `test_vfx_director_runs_all_buffs` so verifica VfxPlayer > 0, nao um VFX por buff.

### F5 - BAIXA - `docs/status.md` e `paridade.md` desatualizados
`status.md` lista E7 "UI em andamento", E8 "parte 1", E10 "pendente" apesar de UI, integracao e build web ja estarem em main. `paridade.md` mantem "gancho (E4b)" na linha do gelo e "placeholder" nas linhas da cena de jogo (ja resolvidos). Sem impacto funcional.

### F6 - BAIXA (informativo) - Ordem das chaves do JSON
Godot serializa JSON com chaves ordenadas (payload do ranking e `estel_pou_save`). Equivalente para `api/scores.js` e para o `loadSave` legado (parse por nome).

### Observacoes de qualidade (screenshots em `evidencias/screenshots/`)
- Coesao visual: boa. Paleta bordo/creme/mel consistente entre menu, selecao, game over e ranking; botoes e cards com moldura de madeira combinam com o tileset da Floresta; urso, fantasma azul e cogumelos legiveis; joystick e botao de pulo com arte propria.
- Desktop 1366: botoes e cards de buff esticam por toda a largura (cards de ~1300 px com texto de ~10 px): legivel mas desproporcional; um container com largura maxima (~640 px) melhoraria.
- Mobile 390x844: escala pixel-perfect inteira gera barras pretas (area util ~288x623 CSS px); nada cortado, tudo centrado. Textos secundarios (descricao dos cards, "Mundo 1/10 - Floresta Encantada", linhas do game over) ficam pequenos (~7 px CSS): legibilidade no limite em celular; o texto do HUD "Mundo..." em marrom claro sobre piso verde claro tem contraste baixo.
- Fonte UrsinhoCozy: o glifo "l" minusculo aparece como barra com pixel extra ("Esco|ha", "F|oresta", "Globa|") em `screenshots/zoom_font_l.png` e `zoom_hud_mobile.png`. Legivel, mas parece defeito do atlas.
- Campo de apelido fica vermelho vivo com foco (parece estado de erro).
- Em touch, joystick e botao de pulo continuam visiveis (escurecidos) atras das telas de selecao e game over; o mapa do jogo transparece parcialmente atras da selecao (so no canto inferior direito), aspecto de sobreposicao inacabada.
- Fantasmas: hitbox menor que o desenho nos rapido/pesado (decisao registrada na auditoria, pendente do Vini); venenoso lilas perde leitura no bioma 6 (ja anotado).
- Nao exercitado no navegador: troca de bioma (120 s), aviso/transicao, escolha de +1 buff, loja de upgrades, pausa - cobertos so por testes headless.

## 4. Amostragem de paridade (valor GDScript = legado)

Conversao so via `units.gd` (px/frame x 60 x 32/36; px x 32/36; celulas e tempos sem conversao).

| Numero | HTML | GDScript |
|---|---|---|
| Velocidades comum/rapido/pesado/errante/venenoso | 1.7 / 2.6 / 1.1 / 1.7 / 1.5 px/frame | `data/legacy/ghost_types.json` igual; `ghost_system.gd:112,155` `Units.speed_px_frame_to_px_s(g.speed*gm*per)*dt` |
| Tamanhos 14/11/22/14/14, minDist 8/10/6/8/10, pesos 50/15/15/12/8 | `GHOST_TYPES` | idem JSON; `ghost_system.gd:47` `Units.px(size)`, minDist x TILE |
| Velocidade base do urso | 3.3 x INITIAL_PACE (0.5) | `GameplayLits.BEAR_BASE_SPEED=3.3`, `bear_model.gd:24` |
| getDiffMult | ghostSpeed x 0.5 x (1+0.10 x fases) | `ghost_system.gd diff_mult()` identico |
| biomeEffective | +0.10 vel/ciclo; -2 s taxa; min 5 | `biome_cycle.gd:30-35` |
| BIOME_DURATION / WARNING / TOTAL | 120 / 10 / 10 | `constants.json` igual |
| POISON_RADIUS / DEBUFF / DURATION / COOLDOWN | 80 px / 0.6 / 2000 ms / 1000 ms | `ghost_system.gd:147-150` (raio via Units.px); duracao como `poison_left` (divergencia ja documentada) |
| JUMP_DURATION; CD base; jump_ext; jump_cd | 0.55; 10 s; +values; 10 x (1-v) | `jump_state.gd:28-45` identico |
| HONEY_PASSIVE_RATE / PICKUP / SPAWN_INTERVAL / MAX / LIFE / R | 1 / 5 / 12 s / 3 / 14 s / 12 px | `honey_system.gd:22-70` (R via Units.px); espacamentos 3 e 1.2 celulas iguais |
| Loja: custos 50,80,120,170,230,300,400,520,680,900; toggles 2500/3000; valores por nivel | `ATTR_DEFS` | `attrs.json` identico; `shop.gd:52-97` |
| speed_temp 4 s x1.8; dash 0.8 s x2.4; freeze_all 4 s; ghost_slow 5 s x0.5; slow_time 4 s x0.4; spirit_trap 5 s; fake_wall 4 s; invisible 5 s; decoy 6 s; roubo +40% 4 s | `applyMapBuff` | `GameplayLits.BUFF_FX` identico |
| teleport 6 celulas; burst/bomb 3.5; empurrao 2.2; orbes >=3 do urso, espacamento 1.2, vida 10, max 4, R 12 | `applyMapBuff`, `spawnCollectible` | `GameplayLits` e `constants.json` identicos |
| Escudo max 1; invuln 0.9 / rebote 1.1; empurrao 1.6 tile; margem de captura -5 | `gameLoop`, `pushGhost` | `GameplayLits` identico |
| Intervalos fixos 15/15/50/30; spray 0.7 x 3 s | `FIXED_INTERVALS`, `SPRAY_*` | `constants.json` / `buffs.json` identico |
| Gelo accel .55, friction .94, maxSpd 3.6, bounce .35 | `BIOME_MECH[2]`, `moveBearIce` | `mech_ice.gd` le cfg e escala por dt x 60 (identico a 60 fps) |
| Morcegos interval 3.5, speed 2.2, r 16, freeze 2 | `BIOME_MECH[4]` | `mech_bats.gd` usa cfg + Units |
| Vazio invertPeriod 8, invertDur 3, portals 2, portalCd 2; portal >= 8 celulas; flash .3/.25 | `mechUpdateVoid` | cfg + `GameplayLits.VOID_*` |
| Geiser sin > 0.6 fogo, > 0.3 aquecendo, invuln 0.4 | `mechGeyserState` | `GameplayLits.GEYSER_*` |
| CAM_CONFIG mobile{9,0.62,0.18} desktop{18,1.78,0.18}; JOY_RADIUS 42 | HTML | `constants.json` igual; confirmado em tela (9 e 18 tiles) |

Divergencias NAO documentadas em `docs/auditoria.md`: nenhuma encontrada. As divergencias deliberadas (relogio de jogo no veneno, `run.rng` no lugar de Math.random, escalas por dt, "mapa que respira" do bioma 10) ja constam na auditoria. Ressalva: `paridade.md` marca o overlay do bioma 10 como "ok (overlay: E8)"; confirmar que foi entregue no E8 (nao verificado em jogo).

## 5. Existencia e teste por sistema

| Sistema | Codigo | Testes (todos PASS) |
|---|---|---|
| 5 classes de fantasma | `ghost_model.gd`, `ghost_system.gd` | test_gameplay_ghosts (class_stats_px, errante_modes, poison, separation, weighted_spawn...) |
| 16 buffs | `buffs.gd`, `gameplay_lits.gd` | test_gameplay_buffs (data_16_buffs, timed_bear_buffs, teleport_swap, light_burst, ghost_steals_orb, shield...), test_gameplay_buffs_flow |
| Mel | `honey_system.gd` | test_gameplay_jump_honey (passive, life_spawn_cap, pickup_radius_and_value) |
| Loja | `shop.gd`, `upgrades_screen.gd` | test_gameplay_shop, test_ui_screens |
| Pulo / pulo duplo | `jump_state.gd` | test_gameplay_jump_honey (jump_basic, jump_attributes, landing_in_wall) |
| Ciclo de 10 biomes com escalada | `biome_cycle.gd` | test_gameplay_biomes (full_cycle_wraps_and_escalates, effective_values, warning_and_transition_timing) |
| 10 mecanicas | `scripts/gameplay/mechanics/mech_*.gd` + 10 cenas marcador | test_gameplay_mech_a, mech_b, mech_factory (cada mecanica com pelo menos 2 testes) |

## 6. Como reproduzir

```
export GODOT_PATH=<caminho do Godot 4.7.2 console>
"$GODOT_PATH" --headless --path games/pegue-o-ursinho/godot --import
"$GODOT_PATH" --headless --path games/pegue-o-ursinho/godot --script res://tests/run_all.gd
"$GODOT_PATH" --headless --path games/pegue-o-ursinho/godot --script res://tools/editor/validate_levels.gd
git diff --stat b375ac4 HEAD -- games/pegue-o-ursinho/index.html games/pegue-o-ursinho/assets games/pegue-o-ursinho/tools api
curl -sI https://estel.games/games/pegue-o-ursinho/web/index.html | grep -ci "^content-security-policy"   # = 1
```
Teste local web: `csp_server.py <repo> <repo>/vercel.json 8766` + Chrome `--headless=new --remote-debugging-port` com Page.navigate, Input.dispatchMouseEvent/KeyEvent/TouchEvent e Network.requestWillBeSent (payload do ranking).
Mutacao (F4): copiar o projeto, trocar o literal em `scripts/gameplay/gameplay_lits.gd`, rodar `run_all.gd` e verificar se aparece algum FAIL.

## 7. Evidencias e limpeza
Em `evidencias/`: import.log, run_all.log, validate_levels.log, logica_vs_biome_maps.txt, biome_cfg_vs_html.txt, legacy_json_vs_html.txt, anchors_checked.txt, anchors_missing.txt, ui_icon_keys.txt, art_ledger_match.txt, art_hash_check.txt, emoji_scan.txt, legacy_intact.txt, git_log.txt, prod_headers.txt e `screenshots/` (d_* desktop local, m_* mobile local, p_* producao, zoom_*).
Processos iniciados por mim (Chrome PID 9888, driver Node PID 27760, servidor Python PID 13028) foram encerrados. Um csp_server.py na porta 8765 (PID 5516) NAO e meu e foi mantido.
