# Bíblia de estilo — Pegue o Ursinho (Godot)

Dono: diretor de arte. Fonte: HANDOFF §8, ajustada ao que foi observado na prática.

## 1. Referências aprovadas (âncora de estilo)
- Urso: `art_source/pixellab/actors/bear/cand_b/` (rotações em `Idle/rotations/*.png`, 48x48, 8 direções).
- Piso: tile "lower" plano (id = `base_tile_ids.lower`, bounding_box x64 y32, 32x32) de `art_source/pixellab/tilesets/biome_01_floresta_encantada/tileset.png` + `tileset_metadata.json`.
- Paleta: `art/palette/estel_cozy.hex` (47 cores) e `docs/arte/estel_cozy_swatch.png`.
- Contact sheet do herói: `docs/arte/contact_sheet_heroi.png`.
- Reprovado (não usar como referência): parede da Floresta v1 (platô de grama).

## 2. Prefixo de estilo (início de toda `description`)
```text
cute cozy pixel art, kawaii storybook mood, soft rounded chunky shapes, warm pastel palette, clean readable silhouette, single dark warm outline (deep brown/plum, never pure black), soft top-left lighting, gentle 2-3 tone shading, no harsh contrast, no gore, friendly and wholesome,
```
Evitar: realistic, dark horror, blood, sharp, gritty, photo, 3D render.

## 3. Parâmetros padrão (com o que se viu na prática)
| Parâmetro | Valor | Observação |
|---|---|---|
| `view` | `high top-down` | em tudo, inclusive objetos e fantasmas |
| `outline` | `single color outline` | fallback: `single color black outline` + remapear contorno para a paleta |
| `shading` | `basic shading` (ou `medium`) | |
| `detail` | `medium detail` | |
| personagem | `mode v3`, sem imagem de referência | v3 sem referência gera 8 direções (não 4); aceitar e usar as 8 ou descartar as diagonais |
| tileset | `create_topdown_tileset`, tile 32, `transition_size 0.5`, standard | standard = 16 tiles (4x4 em 128x128); pro só no aprovado |
| metadados | `tileset_metadata.json` | cada tile traz `corners` (NE/NW/SE/SW = lower/upper) e `bounding_box` (x,y,32,32) no PNG; usar o bounding_box, não a ordem do `id` |
| tile plano | o tile cujos 4 cantos são `lower` | id = `base_tile_ids.lower` (o "upper" idem para `upper`) |

## 4. Escala
- Tile = 32 px. Urso = 48 px ≈ 1,5 tile (altura e largura do sprite, incluindo contorno).
- Fantasmas 40–48 px (pesado 64); ícones/objetos pequenos 32x32.
- Objetos de cenário (árvore, pedra): múltiplos de 32 (32, 64) para encaixar na grade.

## 5. Contorno, luz e sombra
- Contorno único, sempre escuro e quente, nunca `000000`. Real do urso cand_b: `#310308` (índice 0 do .hex). Alternativa ameixa para objetos claros/frios: `#5A2A35` (índice 1).
- Luz do canto superior esquerdo: realce no topo/esquerda, sombra embaixo/direita. 2–3 tons por material (rampa da paleta).
- Sem anti-aliasing, sem semi-transparência (alfa 0 ou 255), sem gradiente suave nem dithering pesado.
- Sombra projetada: elipse pequena, ameixa/marrom em baixa opacidade só no Godot (não pintar no sprite).
- Piso: baixo contraste e sem contorno (o piso é fundo; só os objetos têm contorno). Piso Floresta real: base `#E5EBA1`, variações `#B3D17B/#A6C874`.

## 6. Paleta por bioma (índices no `estel_cozy.hex`, base 0)
| Grupo | Índices | Cores |
|---|---|---|
| contorno | 0–1 | 310308, 5A2A35 |
| urso pelo | 2–5 | 993920, B65921, CD7B34, E9A14D |
| creme (focinho/barriga) | 6–8 | D7A77A, E7C594, FAEEC5 |
| lenço / blush | 9–11 | A1182A, C6302F, E85B4E |
| 1 Floresta | 12–15 | 2F5A3A, 4A7C46 (parede/arbustos, escuros), A6C874, E5EBA1 (piso) |
| 2 Praia | 16–18 | F3DA9B, E2BC72 (areia), 6FD3CF (turquesa) |
| 3 Montanha Gelada | 19–21 | E6F3FA, B8DDF2, 9CC6E6 |
| 4 Pântano | 22–24 | 8C9A55, 5E6B3A, 3E4A2C |
| 5 Caverna | 25–27 | C8A8F0, 8B6BC4, 4E3A7A |
| 6 Vila | 28–30 | D9C8F0 (lavanda), F2A03D (abóbora), 7A6A8E |
| 7 Castelo | 31–33 | E8C79A, C49A66 (arenito), B8323C (vermelho real) |
| 8 Ilhas/Céu | 34–35 | F8FBFF, A9D4F5 (grama da ilha: reusar 12–15) |
| 9 Inferno Fofo | 36–38 | FF9A8A (coral), F25C3A (brasa), 5A3340 (basalto) |
| 10 Cosmos | 39–41 | 6B3FA0, B56BD6, FF9ED8 |
| raridade | 42–44 | 7CE0A0 comum, 8AB4FF raro, FF8A8A épico |
| mel | 45–46 | FFC83D, FFE48A |

Cada bioma pode usar o contorno (0–1) e qualquer cor de grupos "comuns". Fora disso, passar por `reduce_colors`/remap para a paleta antes de importar.

## 7. Checklist de aprovação por asset
1. Silhueta legível em 1x (e em contact sheet 4x nearest).
2. Contorno único, escuro e quente (não preto puro).
3. Luz do canto superior esquerdo.
4. Sem anti-aliasing / semi-transparência sobrando.
5. Dentro da paleta mestre (ou reduzido com `reduce_colors`).
6. Proporção correta para tile de 32 px (urso ≈ 1,5 tile).
7. Mesmo ângulo (high top-down) que o resto.
8. Estilo coerente com o urso cand_b e o piso aprovado.
9. Obstáculo legível (ver lição 1) e piso sem ruído que atrapalhe ler ursinho/fantasma.
Reprovação sempre com motivo objetivo + prompt corrigido.

## 8. Lições aprendidas
1. **Parede deve ser obstáculo legível: massa sólida e mais escura que o piso, nunca um platô do mesmo material.** A parede da Floresta v1 virou um platô de grama (igual ao piso) e foi reprovada; a correção é cerca-viva densa verde-escura (índices 12–13) com contorno. Regra geral: valor (luminosidade) da parede visivelmente menor que o do piso e textura diferente.
2. Descrever a parede como objeto ("dense dark green hedge wall, solid mass") e não como "upper terrain"; evitar palavras que sugiram o mesmo material do piso (grass, meadow, plateau, cliff).
3. v3 sem referência gera 8 direções; planejar custo/uso disso.
4. Conferir sempre o PNG real contra `tileset_metadata.json` (bounding_box) e rodar checagem de alfa/cores antes de aprovar.
5. O contorno real do urso (`#310308`) é bem escuro; manter esse mesmo valor nos demais personagens para coerência, em vez de preto.
