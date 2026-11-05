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
