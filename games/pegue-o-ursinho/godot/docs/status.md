# Status — Pegue o Ursinho → Godot

**Gerações PixelLab:** 532 de 2000 usadas (saldo 1468, reset 05/12/2026). VFX (vfx_workbench) não consumiu gerações.

| Etapa | Responsável | Status | Notas |
|---|---|---|---|
| E0 Setup | Opus | concluída | Godot 4.7.2, templates web, Pillow, agentes |
| E1 Dados legados | godot-architect | concluída | extract_legacy_data.mjs → data/legacy/*.json |
| E2 Esqueleto | godot-architect | concluída | pixel-perfect + ScreenScaler (sem corte em janelas pequenas) |
| E3 Fases editáveis | level-designer | concluída | 10 cenas, dual-grid, validador |
| E4 Paridade gameplay | gameplay-porter | concluída | núcleo, buffs, loja, 10 mecânicas, telas, i18n, save, ranking |
| E5 Arte herói | art-director + pixel-artist | concluída | urso cand_b, tileset Floresta v3, bíblia e paleta |
| E6 Arte por bioma | pixel-artist | concluída | 10 biomas (Pântano = recolor do v1), 5 fantasmas, isca, colecionáveis |
| E7 VFX + UI | vfx-artist, ui-artist | concluída | 28 VFX; 44 ícones, painéis, fonte UrsinhoCozy, cozy_theme |
| E8 Integração | asset-integrator | concluída | tilesets, decor, urso, mecânicas, VFX, fantasmas, props |
| E9 Build web | web-release + Opus | concluída | /games/pegue-o-ursinho/web/; CSP escopada sem 'unsafe-eval' (1 CSP por resposta, verificado em produção) |
| E10 QA | ursinho-qa | concluída | 11/12 critérios aprovados na 1ª passada; F1–F5 corrigidos; 146 testes verdes |

## Pendências / decisões do Vini
- Fantasmas rápido/pesado parecem 1,3–1,4x maiores que o hitbox (mantidos 1:1 por pixel-perfect). Opção: regerar menores.
- Fantasma venenoso com pouco contraste no piso lavanda do bioma 6.
- 06/11/2026: por ordem do Vini a versão Godot virou a oficial. `/games/pegue-o-ursinho/` redireciona (302, `permanent:false` no vercel.json) para `/games/pegue-o-ursinho/web/`; a versão HTML continua em `/games/pegue-o-ursinho/index.html` ("versão clássica"). Para desfazer: remover o bloco `redirects` do vercel.json.
- Ranking: o banco Upstash "pegue-ursinho" (store_jrfSmAeRsfxVOUFo) está arquivado por inatividade; restaurar pelo painel Vercel/Upstash.
- Não exercitado no navegador pelo QA: troca de bioma aos 45 s, escolha de +1 buff, loja, pausa (cobertos por testes headless).
