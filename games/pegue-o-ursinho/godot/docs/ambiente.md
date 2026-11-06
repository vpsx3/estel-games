# Ambiente (registrado em 05/11/2026)

| Item | Valor |
|---|---|
| SO | Windows 10 Home 10.0.19045 |
| Godot | **4.7.2.stable.official.ed1daf0bf** (winget `GodotEngine.GodotEngine`) |
| Executável | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe` |
| Variável | `GODOT_PATH` (escopo User) aponta para o executável `_console.exe` acima |
| Templates de exportação | 4.7.2.stable, só os `web*` (oficiais, release GitHub) em `%APPDATA%\Godot\export_templates\4.7.2.stable\` |
| Python | 3.13.6 + Pillow (pip --user) |
| Node | v24.16.0 / npx 11.13.0 |
| PixelLab MCP | conectado; Tier 1 (Pixel Apprentice), 2000 gerações/ciclo, reset 05/12/2026 |
| Godot MCP | disponível na sessão (opcional) |

Rodar testes:
```bash
"$GODOT_PATH" --headless --path games/pegue-o-ursinho/godot --script res://tests/run_all.gd
```

Notas (E1/E2):
- No Git Bash a variável de usuário `GODOT_PATH` pode não estar exportada; nesse caso: `export GODOT_PATH="/c/Users/vinic/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"`.
- Primeira vez (ou após mexer em `class_name`/assets): `"$GODOT_PATH" --headless --path games/pegue-o-ursinho/godot --import`.
- Regenerar dados legados: `node games/pegue-o-ursinho/godot/tools/extract_legacy_data.mjs`.
- Export web (E9): incluir `data/legacy/*.json` no filtro de recursos não-importados (`include_filter="data/legacy/*.json"`), pois `GameState` os lê via `FileAccess`.
- `tests/run_all.gd` aguarda um frame (`await process_frame`) para os autoloads rodarem `_ready`; testes ficam em `tests/test_*.gd`, estendem `res://tests/case.gd` e expõem `test_*`.

## Escala de tela (ScreenScaler)
- Autoload `autoload/screen_scaler.gd` (registrado em `project.godot`). Viewport base 576x1024, `canvas_items` + `expand`.
- A cada `size_changed` da janela: `f = min(w/576, h/1024)`. `f >= 1` -> `content_scale_stretch = INTEGER` (escala `floor(f)`, pixel-perfect); `f < 1` -> `FRACTIONAL` (escala `f`, sem corte, perde pixel-perfect). `content_scale_factor` fica 1.0 (com `content_scale_size` definido ele multiplicaria o stretch e escalaria em dobro).
- Funcao pura `ScreenScaler.compute(Vector2i)` testada em `tests/test_screen_scaler.gd` (1920x1080, 1366x768, 1024x768, 390x844, 768x1024). No web a janela e medida em px do canvas (inclui devicePixelRatio).
- Com `expand` o viewport visivel cresce no eixo "sobrando"; UI deve usar anchors. A camera (`scripts/gameplay/camera_rig.gd`) usa `get_viewport_rect().size` (tamanho visivel real), nao o base fixo.
