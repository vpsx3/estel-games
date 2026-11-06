# HANDOFF — Pegue o Ursinho → Godot (projeto local + repo + arte PixelLab)

> **Para:** Claude Code (sessão orquestradora em **Claude Opus 5.5**)
> **De:** Vini (owner/lead designer do estel.games)
> **Repo:** https://github.com/vpsx3/estel-games — branch `main`
> **Jogo de origem:** `games/pegue-o-ursinho/index.html` (bundle único HTML/JS, ~2.675 linhas, auditado em 05/11/2026)
> **Idioma de trabalho:** português do Brasil (código, nomes de nós e comentários podem ser em inglês/PT como no original)

> Nota do orquestrador (05/11/2026): ambiente real registrado em `docs/ambiente.md` (Godot 4.7.2 instalado via winget; `GODOT_PATH` aponta para o executável `_console.exe`). Nos comandos abaixo, `godot` = `$GODOT_PATH`.

---

## 1. Missão

1. Criar um **projeto Godot 4 local** do *Pegue o Ursinho*, dentro do próprio clone do repo, com **paridade total de gameplay** com a versão HTML atual.
2. **Reformular toda a arte visual** com o PixelLab (personagens, fantasmas, tiles, decoração, mecânicas de bioma, efeitos das skills, UI, ícones, fonte) — **pixel art, fofo e cozy**, coeso entre os 10 biomes.
3. Deixar **cada fase (bioma) como uma cena editável à mão** no editor do Godot (pintar paredes, mover spawns, posicionar mecânicas) — com validador automático.
4. Manter **tudo versionado no repo** (`main`), incluindo um **build web** publicado em caminho beta, **sem quebrar a versão HTML que está no ar**.

### Papéis
- **Opus 5.5 (sessão principal):** gerente/orquestrador e diretor de arte. Planeja, delega, revisa, aprova, integra, decide conflitos, faz os commits finais de cada etapa. **Não implementa em massa** — delega.
- **Agentes Sonnet 5.5:** executores especializados (seção 4). Cada um tem pastas que "possui"; não edita fora delas sem ordem do orquestrador.

### Regras de execução (padrão do Vini)
- **Sem paradas para aprovação**: executar as etapas em sequência, de forma contínua. Parar somente diante de decisão irreversível e ambígua (ver §11).
- Antes de cada etapa: `git pull --rebase origin main`.
- Commits **por etapa**, mensagens em *conventional commits*, `git add` **com caminhos específicos** — nunca `git add .` / `git add -A`. Push direto em `main` após validação.
- Navegação no `index.html` legado por **âncoras de string** (`grep -n "function drawMap"`), nunca por número de linha fixo.

---

## 2. Estado atual auditado (fonte da verdade = `games/pegue-o-ursinho/index.html`)

| Item | Valor real no código |
|---|---|
| Grid | `BIOME_MAPS`: 10 mapas **30 linhas × 18 colunas** (retrato). `ROWS`/`COLS` derivados dos dados. `0`=livre, `1`=parede |
| Tile legado | `TILE=36` → canvas 648×1080 |
| Biomes | `BIOMES[]` (id, name, icon, wallTint, bgColor, ghostSpeed, ghostSpawnRate, `bearSpawn{c,r}`, `ghostSpawn{c,r}`) |
| Duração | `BIOME_DURATION=45` (override do legado 120) s, `TOTAL_BIOMES=10`, `BIOME_WARNING_TIME=10`, volta ao bioma 1 com escalada de ciclo |
| Loop | `gameLoop` com `dt=min((ts-lastTime)/1000,0.05)`; velocidades em **px/frame @60fps** multiplicadas por `dt*60` |
| Fantasmas | `GHOST_TYPES` comum/rapido/pesado/errante/venenoso (`speed,size,minDist,weight`); `POISON_*` |
| Pace | `INITIAL_PACE=0.5`, `GHOST_PHASE_SCALING=0.10` |
| Mel | `HONEY_PASSIVE_RATE`, `HONEY_PICKUP_VALUE`, `HONEY_SPAWN_INTERVAL`, `HONEY_MAX_ON_MAP`, `HONEY_LIFE`, `HONEY_R` |
| Buffs | `MAP_BUFFS` (16 buffs, `type:'map'|'fixed'`, raridade, pesos `selW/mapW`), `FIXED_INTERVALS`, `SPRAY_*` |
| Atributos (loja) | `ATTR_DEFS` speed_base, jump_cd, jump_ext, double_jump, reroll (custos e valores) |
| Pulo | `JUMP_DURATION=0.55` + atributos |
| Mecânicas de bioma | `BIOME_MECH` (0-based): mushroom, tide, ice, lily, bats, windows, castle, sky, fire, void — **todos os números centralizados aqui** |
| Sprites de mecânica | `MECH_SLOTS` → `assets/biomes/<slug>/<slot>.png` |
| Tiles legados | `assets/biomes/<slug>/{floor,wall_a,wall_b,decor,obstacle}.png` (144×144); variação `wall_a/wall_b` por `tileHash(r,c)%10<6` |
| Urso | `pegue-o-ursinho-bear-spritesheet-bg-removed.png` 256×64, 4 células 64px (north,south,east,west) — ursinho de pelúcia caramelo, focinho creme, corpo redondo, em pé |
| Fantasmas (sprite) | `ghost_classes_spritesheet.png`, células 280×280, linhas = classes, colunas = south,north,east,west — fantasminhas-gota fofos com bochechas rosadas (comum azul-água, rápido verde-água com rastro, pesado grande, errante laranja com olho espiral, venenoso roxo com caveira) |
| Câmera | `CAM_CONFIG` mobile `{tilesAcross:9,maxAspect:0.62,smooth:0.18}`, desktop `{tilesAcross:18,maxAspect:1.78,smooth:0.18}`; `IS_TOUCH` |
| Controles | teclado + joystick virtual (`JOY_RADIUS=42`) + botão de pulo |
| Save | `localStorage['estel_pou_save']` = `{honey, attrs{...}, skins{owned,equipped}}` |
| Idioma | `localStorage['estel_lang']` (PT/EN), `STRINGS_GAME`, `BIOME_NAMES_EN`, `BUFF_EN`, `MAP_FX_EN`, `ATTR_EN` |
| Ranking | `POST /api/session {game}` → `{token}`; `GET /api/scores?game=`; `POST /api/scores {game,nick,seconds,ghosts,biomeReached,token}` — token HMAC com `iat` do servidor, anti-replay |
| `GAME_ID` | `'pegue-o-ursinho'` |
| Analytics | gtag `G-ENR25YEZMV` |
| Gerador de mapas | `games/pegue-o-ursinho/tools/generate_biome_maps.py` (densidades-alvo por bioma, flood-fill, `MIN_SPAWN_DIST=10`) |
| CSP (vercel.json) | `script-src 'self' 'unsafe-inline' https://www.googletagmanager.com` — **sem** `'wasm-unsafe-eval'` (bloqueia Godot web; ver §9) |

> O agente que portar o código **deve reauditar** o `index.html` no início (pode ter mudado). Qualquer divergência com esta tabela: o código vence; registre em `docs/auditoria.md`.

---

## 3. Decisões técnicas fixas

### 3.1 Engine
- **Godot 4.4 ou superior, estável, GDScript.** Versão em uso: ver `docs/ambiente.md` (4.7.2). Usar `$GODOT_PATH`.
- Templates de exportação **da mesma versão** instalados (para o build web).
- Renderer: **Compatibility** (obrigatório para web/mobile).
- Usar **`TileMapLayer`** (não o `TileMap` depreciado) e `@export_tool_button` (4.4+) para os botões de editor.
- Se o servidor MCP `godot` estiver disponível, pode ser usado; senão, CLI (`godot --headless --path ... --script ...`). Não é bloqueante.

### 3.2 Pixel-perfect
- `rendering/textures/canvas_textures/default_texture_filter = Nearest`
- `rendering/2d/snap/snap_2d_transforms_to_pixel = true` e `snap_2d_vertices_to_pixel = true`
- `display/window/stretch/mode = canvas_items`, `aspect = expand`, `scale_mode = integer`
- Importação de PNG: filtro off, mipmaps off, `compress/mode = Lossless`.

### 3.3 Escala de mundo
- **Novo tile = 32 px**. Mundo = 18×32 = **576 px** × 30×32 = **960 px**.
- Viewport base retrato: **576 × 1024**. Câmera porta `CAM_CONFIG` (mobile segue o urso em 2 eixos com ~9 tiles de largura; desktop mostra as 18 colunas e rola na vertical).
- **Conversão obrigatória** de unidades legadas (documentar em `scripts/core/units.gd`):
  - `TILE_SCALE = 32.0 / 36.0`
  - velocidade px/frame → px/s: `godot = legado * 60.0 * TILE_SCALE`
  - raios/distâncias em px (`HONEY_R`, `POISON_RADIUS`, `COLLECT_R`, `r` dos morcegos, raio de `size` dos fantasmas, etc.): `* TILE_SCALE`
  - valores em **células** e **tempos** (s/ms) **não mudam**.
- **Balanceamento é intocável**: todos os números vêm de `data/legacy/*.json` extraídos do HTML e só passam pela conversão de unidade acima.

### 3.4 Mapas: grade lógica + grade visual (dual-grid)
- **`Logica` (TileMapLayer)**: grade 18×30 de células 32 px com **apenas 2 tiles** — `piso` e `parede`. É **aqui que o Vini pinta**. Fonte da colisão e do pathfinding. Oculta em runtime.
- **`Visual` (TileMapLayer)**: grade **dual** (19×31), deslocada `(-16,-16)`. Cada tile visual olha as 4 células lógicas em volta (NW, NE, SW, SE) e escolhe o tile Wang de cantos do tileset do bioma. **Gerada automaticamente** por script `@tool` quando `Logica` muda (sinal `changed`) + botão "Repintar visual".
- **`DetalhePiso` (TileMapLayer)**: variações de piso — pintável à mão; botão "Espalhar detalhes" com seed fixa.
- **`Decor` (Node2D, y-sort)**: objetos decorativos sem colisão.
- **`Mecanicas` (Node2D)**: instâncias de cenas de mecânica posicionáveis.
- **`Spawns`**: `Marker2D` **`SpawnUrso`** e **`SpawnFantasma`** (snap em célula).
- **`BiomeConfig` (Resource `.tres`)** por bioma: nome PT/EN, ícone, cores, `ghostSpeed`, `ghostSpawnRate`, parâmetros de `BIOME_MECH`, referência ao tileset — tudo `@export`.

Fallback das mecânicas: se `Mecanicas` tiver filhos, usar as posições colocadas à mão; se vazio, comportamento procedural original. Mecânicas globais (maré, gelo, vento, inversão) são só config.

---

## 4. Agentes

Definições em `.claude/agents/ursinho-*.md` (raiz do repo), todos `model: sonnet`. Protocolo do orquestrador:
- Ao delegar, passe: etapa, arquivos de entrada, pastas que o agente possui, definição de pronto, formato do relatório.
- Agentes com pastas disjuntas podem rodar em paralelo. Nunca dois na mesma pasta ao mesmo tempo.
- Revise todo relatório; rode os testes antes do commit.
- Opus é o **diretor de arte final**. Primeiro aprova o **urso** e o **tileset da Floresta**.
- Manter `docs/status.md` atualizado.

---

## 5. Estrutura de pastas

```
estel-games/
├─ .claude/agents/ursinho-*.md
├─ .vercelignore                        (exclui godot/ do deploy)
├─ vercel.json                          (+1 regra de header escopada, §9)
└─ games/pegue-o-ursinho/
   ├─ index.html                        (LEGADO — NÃO ALTERAR)
   ├─ assets/ tools/                    (legado — não alterar)
   ├─ web/                              (build web exportado)
   └─ godot/
      ├─ project.godot  export_presets.cfg  icon.svg  .gitignore
      ├─ autoload/      game_state.gd, save.gd, i18n.gd, api_client.gd, audio.gd, events.gd
      ├─ scripts/core/  units.gd, rng.gd, device.gd
      ├─ scripts/gameplay/  bear.gd, ghost.gd, ghost_spawner.gd, buffs.gd, honey.gd, biome_runner.gd, camera_rig.gd, input_touch.gd
      ├─ scripts/level/ level_root.gd (@tool), dual_grid_painter.gd (@tool), biome_config.gd (Resource)
      ├─ scenes/        main.tscn, game.tscn, actors/, mechanics/, vfx/, ui/
      ├─ levels/        biome_01_floresta_encantada.tscn … biome_10_dimensao_dos_fantasmas.tscn, _template_biome.tscn
      ├─ data/legacy/   maps.json, biomes.json, biome_mech.json, ghost_types.json, buffs.json, attrs.json, constants.json, strings_pt.json, strings_en.json
      ├─ data/biomes/   biome_01.tres … biome_10.tres
      ├─ tilesets/      editor_logic.tres, biome_01.tres … biome_10.tres, corner_maps/
      ├─ assets/        actors/, tiles/, decor/, mechanics/, vfx/, ui/, fonts/, audio/  (só arte APROVADA)
      ├─ art/palette/   estel_cozy.hex
      ├─ art_source/pixellab/  (saídas brutas + JSON + ledger.csv)
      ├─ themes/        cozy_theme.tres
      ├─ i18n/          strings.csv
      ├─ tools/         extract_legacy_data.mjs, editor/validate_levels.gd, import/*.py
      ├─ tests/         run_all.gd + test_*.gd
      └─ docs/          HANDOFF, status.md, ambiente.md, auditoria.md, paridade.md, como-editar-fases.md, arte/, qa/
```

---

## 6. Etapas

> Cada etapa: `git pull --rebase origin main` → delegar → revisar → testar → `git add <caminhos>` → commit → `git push origin main`.

- **E0 — Setup (Opus):** agentes, `docs/status.md`, ambiente. `chore(ursinho-godot): agentes e documentação de handoff`
- **E1 — Extração dos dados legados (architect):** `tools/extract_legacy_data.mjs` (Node) localiza cada `const NOME=` por âncora, recorta literal balanceado, avalia em `vm` isolado → `data/legacy/*.json`. Constantes simples → `constants.json`. Teste: 10 mapas 30×18 idênticos a `BIOME_MAPS`. `feat(ursinho-godot): extrai dados legados do index.html para JSON`
- **E2 — Esqueleto (architect):** `project.godot` (§3.1/§3.2), input map (`move_up/down/left/right` WASD+setas, `jump` Espaço, `pause` Esc), autoloads, `.gitignore`, `.vercelignore` na raiz, `tests/run_all.gd`. `feat(ursinho-godot): esqueleto do projeto Godot 4 pixel-perfect`
- **E3 — Fases editáveis (level-designer):** BiomeConfig, level_root, dual_grid_painter, template, 10 cenas, tileset de editor, validador headless + botão, placeholder visual dos PNGs legados, `docs/como-editar-fases.md`. `feat(ursinho-godot): 10 fases como cenas editáveis + validador`
- **E4 — Paridade de gameplay (gameplay-porter), em paralelo com E5–E7:** movimento+colisão → fantasmas → ciclo de biomes → mecânicas → pulo → mel → buffs → loja → HUD → câmera → touch → i18n → save (web: `localStorage['estel_pou_save']` via `JavaScriptBridge`; fora: `user://save.json`) → ranking (`HTTPRequest`, falha silenciosa offline) → telas. Commits por subsistema.
- **E5 — Direção de arte + lote herói:** bíblia, paleta, urso (rotações+idle+walk) e tileset da Floresta. `feat(ursinho-art): bíblia de estilo, paleta e lote herói`
- **E6 — Arte por bioma:** tileset Wang, variações de piso, 4–6 decor, mecânicas; depois 5 fantasmas, colecionáveis. Commit por bioma.
- **E7 — VFX e UI.**
- **E8 — Integração:** tilesets Wang reais, SpriteFrames, VFX, Theme.
- **E9 — Build web:** §9.
- **E10 — QA independente + correções.**

---

## 7. Fases no Godot

### 7.1 Hierarquia de cada `levels/biome_XX_<slug>.tscn`
```
BiomeXX (Node2D, level_root.gd @tool)   ← export: config: BiomeConfig, botões: Repintar visual | Espalhar detalhes | Validar fase
├─ Visual         (TileMapLayer, dual-grid, gerado)
├─ DetalhePiso    (TileMapLayer, editável)
├─ Logica         (TileMapLayer, 18×30, piso/parede — EDITAR AQUI)
├─ Decor          (Node2D, y_sort_enabled)
├─ Mecanicas      (Node2D)
└─ Spawns
   ├─ SpawnUrso      (Marker2D)
   └─ SpawnFantasma  (Marker2D)
```

### 7.2 `docs/como-editar-fases.md`
1. Abrir `levels/biome_03_montanha_gelada.tscn`. 2. Selecionar `Logica` → pintar parede/piso (borda sempre parede). 3. `Visual` se repinta (ou botão). 4. Arrastar spawns. 5. Mecânicas em `Mecanicas` (vazio = procedural). 6. Números no Inspector do `config`. 7. **Validar fase**. 8. F6 roda só a fase. 9. Versionar: pedir ao Claude Code "commita minhas edições da fase 3".

### 7.3 Validador (`tools/editor/validate_levels.gd`)
Erros: célula livre não conectada; spawn em parede/fora; distância urso↔fantasma < 10 células; borda aberta; mecânica em parede. Avisos: densidade fora de ±2pp da meta; área livre < 80 células. Roda headless em `tests/run_all.gd`.

---

## 8. Arte com PixelLab

### 8.1 Bíblia de estilo
Prefixo (inglês, início de toda `description`):
```text
cute cozy pixel art, kawaii storybook mood, soft rounded chunky shapes, warm pastel palette, clean readable silhouette, single dark warm outline (deep brown/plum, never pure black), soft top-left lighting, gentle 2-3 tone shading, no harsh contrast, no gore, friendly and wholesome,
```
| Parâmetro | Valor |
|---|---|
| `view` | `high top-down` em tudo |
| `outline` | `single color outline` (fallback `single color black outline` + correção de paleta) |
| `shading` | `basic shading` ou `medium shading` |
| `detail` | `medium detail` |
| Tile | 32 px |
| Urso | ~48 px |
| Fantasmas | 40–48 px; pesado 64 px |
| Ícones | 32×32 |
| Paleta | `art/palette/estel_cozy.hex` (≤48 cores) |
Evitar nos prompts: realistic, dark horror, blood, sharp, gritty, photo, 3D render.

### 8.2 Urso — `create_character`
Caramelo, focinho/barriga creme, orelhas redondas, bochechas rosadas, corpo redondo, em pé, olhos pretos brilhantes.
```text
<prefixo> chubby round teddy bear cub standing upright, caramel brown plush fur, cream muzzle and round cream belly patch, small round ears with cream inside, big shiny black eyes, rosy blush cheeks, tiny stubby arms and legs, tiny red scarf, adorable and brave
```
`mode:"v3"`, `size:48`, 2 candidatos. Alternativa: célula south do spritesheet legado como `reference_image_url`.
Animações (4 direções): `idle` breathing-idle; `walk` walking-6-frames; `jump` v3 "small happy hop in place, squash on landing" 8f; `dash` running-slide; `caught` (south) "startled jump, arms up in surprise, then dizzy wobble" 8f; `celebrate` (south) "cheering with both arms up, little bounce" 8f. Shield/invisible = shader.

### 8.3 Isca (`decoy`)
`create_map_object` 32×32 "small stitched plush teddy bear toy sitting, patched ear, button eyes" + wobble 6f.

### 8.4 Fantasmas
Base: `<prefixo> cute round jelly ghost blob, glossy highlight on top, small floating tail, tiny nub arms, rosy cheeks,` + comum `pastel aqua blue, friendly mischievous smile` (44) / rapido `mint teal, determined eyebrows, little speed streaks behind it` (40) / pesado `big chunky pale aqua ghost, heavier and wider, confident grin` (64) / errante `soft orange, one spiral dizzy eye, tongue out, floating sparkle dots` (44) / venenoso `lavender purple, small cute skull mark on forehead, purple wisps curling around, dripping tail` (44). Direções south/north/east/west; animação "floating bob loop, soft squash and stretch" 6f. Estados frozen/trapped/boost = shader.

### 8.5 Biomes
Tileset Wang `create_topdown_tileset`: tile 32, `transition_size 0.5`, standard (pro na final se orçamento). Importador suporta 16 e 25 tiles.
| # | Bioma | Piso | Parede | Borda | Decor | Mecânicas |
|---|---|---|---|---|---|---|
| 1 | Floresta Encantada | soft mossy meadow grass with tiny clovers | round bushy hedges with cute tree trunks, deep green leaves | grass tufts and tiny daisies | toadstools, flores, vaga-lumes, toco | mushroom: cogumelo-mola vermelho (wobble 6f + bounce 8f) |
| 2 | Praia dos Coqueiros | warm golden sand with tiny shells | clusters of small palm trees and smooth beige rocks | damp sand edge | estrela-do-mar, concha, balde, guarda-sol | water (mar raso loop 6f), foam (6f) |
| 3 | Montanha Gelada | slippery pale blue ice with soft snow patches | snowy rounded pine trees and snow-capped boulders | fluffy snow drift | boneco de neve, cristais, trenó | ice_sparkle VFX |
| 4 | Pântano Verde | soft muddy moss ground with small puddles | twisted friendly mangrove roots and tall reeds | muddy bank with cattails | taboas, sapinho, cogumelo | lilypad (6f), lilypad_sink (8f) |
| 5 | Caverna dos Ecos | dark violet cave floor with tiny glowing crystal specks | rounded purple cave rocks with glowing pastel crystals | pebbles and glow moss | cogumelos luminosos, estalagmites, lanterna | bat_sheet: morcego 32px voo 6f 4 dir |
| 6 | Vila Assombrada | old cobblestones with fallen autumn leaves, soft lavender tint | crooked cute haunted cottage walls and wooden fences | moss between stones | abóboras, lampiões, gato preto | window_eyes (blink 6f + glow 6f) |
| 7 | Castelo do Rei | polished warm sandstone castle floor tiles | castle stone walls with small royal banners | stone trim | tochas, armadura, estátua, vaso | gate (8f), carpet (3 variações) |
| 8 | Ilhas Flutuantes | soft green grass on a floating island | puffy white clouds | island edge with dangling roots | pipas, passarinhos, flores | platform (6f), wind VFX |
| 9 | Inferno Fofo | warm cozy volcanic rock with soft glowing candy-like cracks | rounded marshmallow-shaped dark basalt with cute lava drips | warm ember glow | foguinhos, fonte termal, pedra com carinha | geyser_idle 6f, geyser_fire 8f, fire_trail 6f |
| 10 | Dimensão dos Fantasmas | starry cosmic purple floor with soft nebula swirls | translucent glowing ghost-crystal pillars | stardust | velas, relógio derretido, estrelinhas | portal 8f |

Colecionáveis: `honey_pot` 32×32 + sparkle 6f; `buff_orb` 3 cores por raridade (`#7CE0A0`, `#8AB4FF`, `#FF8A8A`) + pulse 6f.

### 8.6 VFX (`vfx_workbench`, export `--game-pack`)
16 buffs: speed_temp, freeze_all, teleport, ghost_slow, dash, spirit_trap, fake_wall, light_burst, invisible, slow_time, swap, lightning, light_bomb, rebound, decoy, shield. Eventos: jump, honey_pickup, poison_aura, poisoned, ghost_spawn, ghost_eliminated, caught, biome_transition, biome_warning.

### 8.7 UI
Ícones 32×32 para 16 buffs, 5 atributos, mel, cronômetro, fantasma, troféu, 10 biomas. Painéis/botões `create_ui_asset` ("cozy wooden storybook panel with honey-gold trim and rounded corners, soft cream inner area"): 9-slice, botão (4 estados), card de buff por raridade, barra de tempo, joystick, botão de pulo. Fonte `create_font` "rounded cute pixel font, thick, highly readable" com acentos PT. Telas: início, seleção de 3 buffs, loja, anúncio de bioma, HUD, pausa, game over + nick, ranking.

### 8.8 Disciplina de custo
`get_balance` antes de cada lote; registrar no `ledger.csv` e `docs/status.md`. Prototipar barato, pro só no aprovado. Saldo acabou: pausar só a arte e reportar.

---

## 9. Repo e publicação (Vercel)
- `.vercelignore` (raiz): `games/pegue-o-ursinho/godot`.
- Build web em `games/pegue-o-ursinho/web/` → beta em `https://estel.games/games/pegue-o-ursinho/web/`. HTML continua oficial.
- Export **single-thread** (sem COOP/COEP).
- CSP: nova regra escopada `source: /games/pegue-o-ursinho/web/(.*)` com CSP global + `'wasm-unsafe-eval'` e `blob:` em `script-src` + `worker-src 'self' blob:`. Validar precedência; se não funcionar, reportar antes de mexer na global.
- Shell HTML com gtag `G-ENR25YEZMV` e link "versão clássica" para `../`.
- Nenhum arquivo > 50 MB. Não criar entrada no portal sem ordem do Vini.

---

## 10. Critérios de aceite
- [ ] Projeto abre sem erros; `tests/run_all.gd` passa headless.
- [ ] 10 fases como cenas; `Logica` idêntica a `BIOME_MAPS`; validador verde.
- [ ] Editar `Logica` repinta `Visual`; spawns/mecânicas arrastáveis; `docs/como-editar-fases.md` existe.
- [ ] Paridade numérica via `units.gd` (teste compara com `data/legacy`).
- [ ] 5 fantasmas, 16 buffs, mel, loja, pulo/duplo, ciclo de 10 biomes com escalada, 10 mecânicas — "ok" em `docs/paridade.md`.
- [ ] Câmera conforme `CAM_CONFIG`; joystick e pulo touch.
- [ ] PT/EN via `estel_lang`; save via `estel_pou_save`.
- [ ] Ranking com o mesmo `GAME_ID`.
- [ ] Toda arte nova (PixelLab), aprovada no ledger; nenhum emoji na UI.
- [ ] VFX para os 16 buffs + eventos.
- [ ] Build web no ar sem erro de CSP; HTML intacto (`git diff` vazio em `index.html`, `assets/`, `api/`).
- [ ] Commits escopados; `docs/status.md` com gerações gastas.

## 11. Intocáveis e limites
- **Não alterar**: `games/pegue-o-ursinho/index.html`, `games/pegue-o-ursinho/assets/`, `games/pegue-o-ursinho/tools/`, `api/`, analytics, outros jogos, `index.html` do portal, regras existentes do `vercel.json`, variáveis de ambiente da Vercel.
- **Não mudar** balanceamento, anti-cheat/HMAC ou contrato da API.
- Não ficar perguntando ao Vini se pode prosseguir; só perguntar em conflito ou decisão dele.
