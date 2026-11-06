# Como editar as fases

Cada fase e uma cena em `levels/` (ex.: `levels/biome_03_montanha_gelada.tscn`). Nao precisa programar.

## Passo a passo

1. **Abrir a fase.** No painel FileSystem, de dois cliques em `levels/biome_03_montanha_gelada.tscn`. A cena aparece no editor 2D com a arvore `Biome03 > Visual, DetalhePiso, Logica, Decor, Mecanicas, Spawns`.
2. **Pintar a Logica.** Selecione o no `Logica`. No painel TileMap (embaixo) aparecem so 2 tiles: o claro e o **piso**, o escuro com X e a **parede**. Pinte com o pincel; apague com o botao direito/borracha (celula vazia conta como piso). A **borda do mapa (18 colunas x 30 linhas) tem de continuar parede**. Dica: o X vermelho marca onde nao se anda. A colisao vem desta camada.
3. **Visual se repinta sozinho.** Ao pintar na `Logica`, a camada `Visual` (grade dual 19x31, deslocada meia celula) se atualiza. Se algo ficar estranho, selecione o no raiz (`Biome03`) e clique **Repintar visual** no Inspector.
4. **Mover spawns.** Em `Spawns`, arraste `SpawnUrso` e `SpawnFantasma`; eles encaixam no centro da celula. Mantenha no minimo 10 celulas entre os dois e nunca sobre parede.
5. **Mecanicas.** Instancie cenas de mecanica como filhas de `Mecanicas`. Se `Mecanicas` estiver **vazio**, o jogo usa o comportamento procedural original; se tiver filhos, usa as posicoes que voce colocou. Nao coloque mecanica em parede. Mare, gelo, vento e inversao sao so configuracao (nao tem no para posicionar).
6. **Numeros no Inspector.** No no raiz, o campo `Config` abre o `BiomeConfig` (nomes PT/EN, cores, `ghost_speed`, `ghost_spawn_rate`, parametros `mech`, tileset, meta de densidade). Edite la; nunca no codigo. Se voce mudou o mapa a mao e a densidade de paredes saiu da meta, marque `Edicao Manual` no no raiz: o validador passa a tratar isso como **aviso** em vez de erro. `Detalhe Density` e `Detail Seed` controlam o botao **Espalhar detalhes** (precisa de `detail_tiles` no config; sem ele nada acontece).
7. **Validar fase.** Clique **Validar fase** no Inspector do no raiz. O resultado sai na aba Saida: erros (vermelho) bloqueiam, avisos (amarelo) so informam. Erros: borda aberta, spawn em parede/fora, urso e fantasma a menos de 10 celulas, celula livre isolada, mecanica em parede, densidade fora da meta +-2 pontos percentuais. Aviso: area livre menor que 80 celulas. Para validar as 10 de uma vez pelo terminal:
   `"$GODOT_PATH" --headless --path games/pegue-o-ursinho/godot --script res://tools/editor/validate_levels.gd`
8. **Testar.** Com a cena aberta aperte **F6** (Executar cena atual) para rodar so essa fase. A camada `Logica` fica oculta em runtime.
9. **Versionar.** Peca ao Claude Code: "commita minhas edicoes da fase 3".

## Referencia rapida

- Metas de densidade de paredes: 37, 31, 49, 37, 48, 34, 66, 47, 62 e 71 % (fases 1 a 10), medidas nos mapas originais.
- Tilesets reais (PixelLab) em `tilesets/biome_XX.tres` + `tilesets/corner_maps/biome_XX_<slug>.json` + variacoes de piso em `tilesets/biome_XX_details.tres` (campo `detail_tiles`). Reimportar/atualizar: `python tools/import/import_all.py` -> `godot --headless --import` -> `godot --headless --path . --script res://tools/import/apply_to_levels.gd` (repinta Visual, espalha DetalhePiso ~10% do piso e 6-12 itens de Decor; refaz so DetalhePiso/Decor, nunca Logica/Spawns/Mecanicas). Converter um tileset avulso: `python tools/import/pixellab_tileset_to_godot.py <pasta> --biome N --slug nome`. Capturas reais: `tools/import/capture_game.gd` / `capture_level.gd`.
- Cena base para uma fase nova: `levels/_template_biome.tscn`.
- Recriar as 10 fases do zero a partir dos dados legados (APAGA edicoes): `--script res://tools/editor/import_legacy_levels.gd`.
