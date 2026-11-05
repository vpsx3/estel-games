# Auditoria do `index.html` legado (E1, 05/11/2026)

Fonte: `games/pegue-o-ursinho/index.html`. Extração: `node tools/extract_legacy_data.mjs` (âncoras `const NOME=`, avaliação em `vm` isolado). Conferido contra a tabela §2 do HANDOFF. **O código vence** em qualquer divergência.

## Conferido (sem divergência)

| Item §2 | Resultado |
|---|---|
| Grid | `BIOME_MAPS` = 10 mapas, 30 linhas x 18 colunas, só 0/1. `ROWS=30`, `COLS=18` derivados |
| Tile / canvas | `TILE=36`, `CW=648`, `CH=1080` |
| Duração | `BIOME_DURATION=120`, `TOTAL_BIOMES=10`, `BIOME_WARNING_TIME=10` |
| `BIOMES` | 10 entradas com id, name, icon, wallTint, bgColor, ghostSpeed, ghostSpawnRate, bearSpawn{c,r}, ghostSpawn{c,r} (+ `MAP_TEMPLATE`, referência a `BIOME_MAPS`, descartado do JSON) |
| Fantasmas | `GHOST_TYPES` comum/rapido/pesado/errante/venenoso com speed,size,minDist,weight; `POISON_RADIUS=80`, `POISON_DEBUFF=0.6`, `POISON_DURATION=2000`, `POISON_COOLDOWN=1000` |
| Pace | `INITIAL_PACE=0.5`, `GHOST_PHASE_SCALING=0.10` |
| Mel | `HONEY_PASSIVE_RATE=1`, `HONEY_PICKUP_VALUE=5`, `HONEY_SPAWN_INTERVAL=12`, `HONEY_MAX_ON_MAP=3`, `HONEY_LIFE=14`, `HONEY_R=12` |
| Buffs | `MAP_BUFFS` = 16 (12 `map`, 4 `fixed`: ghost_slow, spirit_trap, lightning, decoy), com rar/selW/mapW; `FIXED_INTERVALS`, `SPRAY_SLOW_MULT=0.7`, `SPRAY_SLOW_DUR=3` |
| Atributos | `ATTR_DEFS` = speed_base, jump_cd, jump_ext, double_jump, reroll (custos 50..900; toggles 2500/3000) |
| Pulo | `JUMP_DURATION=0.55` |
| Mecânicas | `BIOME_MECH` 0..9: mushroom, tide, ice, lily, bats, windows, castle, sky, fire, void; `MECH_SLOTS` conforme §2 |
| Câmera | `CAM_CONFIG` mobile {9, 0.62, 0.18}, desktop {18, 1.78, 0.18} |
| Controles | `JOY_RADIUS=42` |
| Save | `SAVE_KEY='estel_pou_save'`; `DEFAULT_SAVE={honey, attrs{5 atributos}, skins{owned:['default'],equipped:'default'}}` |
| Idioma | `STRINGS_GAME` pt/en (73 chaves cada, mesmas chaves), `BIOME_NAMES_EN` (10), `BUFF_EN` (23), `MAP_FX_EN` (16), `ATTR_EN` (5) |
| `GAME_ID` | `'pegue-o-ursinho'` |

Sanidade dos mapas (conferida por script): borda externa 100% parede nos 10 mapas; célula do urso e do fantasma livres em todos; distância urso↔fantasma entre 14,3 e 16,6 células (>= 10, `MIN_SPAWN_DIST`).

Densidade de paredes (% das 540 células): 1=37,0 · 2=31,1 · 3=48,9 · 4=37,0 · 5=47,6 · 6=33,5 · 7=66,1 · 8=46,9 · 9=62,0 · 10=71,1.

## Divergências e observações

1. **`obstacle.png` não é mais usado.** §2 lista `{floor,wall_a,wall_b,decor,obstacle}.png`; o código tem `TILE_SLOTS=['floor','wall_a','wall_b','decor']` (comentário: 'obstacle' removido porque parecia atravessável). Vale o código: 4 slots.
2. **`BUFF_EN` contém ids legados sem uso** (`item_cd`, `resist`, `post_jump`, `light_steps`; os de atributos `speed_base/jump_cd/jump_ext` também) — passivos removidos do fluxo na "Etapa 6" do jogo. Não existem em `MAP_BUFFS`; mantidos no JSON para fidelidade, o port pode ignorá-los. Os 16 ids de `MAP_BUFFS` têm tradução EN.
3. **`ALL_BUFFS`** é só cópia de `MAP_BUFFS` (não extraído separadamente). `RAR_LABEL` (PT) vai em `buffs.json` (`rarity_labels`) e `strings_pt.json` (`rarity`).
4. **Declarações compostas**: `SPAWN_INTERVAL_BASE=8, COLLECT_LIFE=10, MAX_COLLECT=4, COLLECT_R=12` e `BEAR_CELL_W/H` são uma única `const` com vírgulas; `JOY_RADIUS` fica no meio de uma linha (`let joyId...;const JOY_RADIUS=42;`). O extrator trata ambos.
5. **Constantes de gameplay também incluídas em `constants.json`** além das listadas: `ROWS, COLS, CW, CH, GHOST_CELL_W/H, GHOST_SPRITE_ROW, GHOST_DIR_COL, BEAR_CELL_W/H, BEAR_DIR_COL, BEAR_DRAW_MULT, BIOME_SLUGS, TILE_SLOTS, GHOST_PALETTES, DEFAULT_SAVE, SPAWN_INTERVAL_BASE, COLLECT_LIFE, MAX_COLLECT, COLLECT_R, FIXED_INTERVALS, SPRAY_SLOW_*`. `FIXED_INTERVALS`/`SPRAY_*` também aparecem em `buffs.json` (mesma fonte).
6. **Não extraído (não são dados puros)**: `canvas, ctx, gameShell, fsBtn, fsHint, joyEl, knob, jBtn` (DOM), `IS_TOUCH, DEVICE, CAM` (ambiente), `ghostSheet, bearSheet, biomeTiles` (Image), `maxJumps` (função), `mechTiles` e `joyVec` (estado de runtime vazio). `CAM` é `CAM_CONFIG[DEVICE]`; o port resolve via `Device.tier()`.
7. **Emojis**: `BIOMES[].icon`, `MAP_BUFFS[].icon`, `ATTR_DEFS[].icon` e várias strings de UI usam emoji. Critério de aceite §10 proíbe emoji na UI final: o port deve trocar por ícones PixelLab (os dados legados ficam intactos).
8. **Velocidade dos fantasmas**: o fator efetivo combina `GHOST_TYPES[].speed`, `BIOMES[].ghostSpeed`, `INITIAL_PACE` e `GHOST_PHASE_SCALING` (todos px/frame @60fps antes da conversão por `Units`); a fórmula exata está no `gameLoop` e deve ser portada na etapa E4, não aqui.
9. Densidades reais dos mapas 7 a 10 (62% a 71%) são altas; o validador do E3 (±2pp da meta) deve usar como meta o valor atual do `BIOME_MAPS`/`generate_biome_maps.py`, não um número do HANDOFF.

## E4a - literais fora de `constants.json` (gameplay-porter, 05/11/2026)

Numeros "soltos" no `index.html` que nao estao em `data/legacy/constants.json`. Mantidos IGUAIS em `scripts/gameplay/gameplay_lits.gd` (unidade legada; convertidos por `Units` no ponto de uso). Nenhum foi alterado.

| Literal | Valor | Onde no JS |
|---|---|---|
| Velocidade base do urso | 3.3 px/frame (x `INITIAL_PACE`) | `initGame` (`bear.speed`) |
| Raio do urso | 14 px | `initGame` (`bear.size`) |
| Caixa de colisao | `size * 0.45` | `canMove` |
| Deslize na parede | 30% do passo | `moveBear` |
| Margem de captura | `size_urso + size_fantasma - 5` px | `gameLoop` |
| Aterrissagem | alcance < 6 px, passo 8 px/frame | `updateEffects` |
| CD base do pulo | 10 s | `initGame`, `recalcPassives` (`jumpCdMax`) |
| Escalada por ciclo | +0.10 velocidade, -2 s de taxa, minimo 5 s | `biomeEffective` |
| Errante | modo 4000 + rand*4000 ms; retarget 2000 ms | `makeGhost`, `moveGhosts`, `wanderMove` |
| Transicao | fantasmas ocultos 0.5 s, invuln 1 s, fantasma a >= 10 celulas | `executeBiomeTransition` |
| Escudo/rebote | invuln 0.9 s / 1.1 s; empurrao `TILE*1.6` | `gameLoop`, `pushGhost` |
| Mel | longe do urso >= 3 celulas, espacamento 1.2 celulas | `spawnHoney` |
| Joystick | zona morta 0.18 | `joyMove` |
| `dt` maximo | 0.05 s | `gameLoop` |

### Divergencias deliberadas (E4a)
1. **Veneno usa relogio de jogo.** JS: `bear.poisonEnd = Date.now() + POISON_DURATION` (relogio de parede, continua contando em pausa/escolha de buff). Port: `bear.poison_left` decrementado por `dt` (so conta enquanto o jogo roda). Duracao e cooldown iguais.
2. **Deslize de aterrissagem** (`st=min(d,8)` por frame no JS) usa `8 px/frame` convertido para px/s x `dt` (identico a 60fps; independente de FPS).
3. **Suavizacao da camera** (`+= (alvo-cam)*0.18` por frame): aqui `alpha = 1-(1-0.18)^(dt*60)` (identico a 60fps).
4. **Fantasma sobre o urso (d == 0)**: `pushGhost` do JS nao move (divisao por `||1` com delta 0); mantido igual.
5. **Perseguicao** dos fantasmas e linha reta atravessando paredes (sem pathfinding), como no JS; so o errante vagando respeita `canMove`.
6. **Letterbox** do `maxAspect` na camera: o JS corta a largura do canvas; no Godot so o zoom usa a largura limitada (area extra mostra a cor de fundo). Acabamento visual: E4c/E8.
