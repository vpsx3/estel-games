---
name: ursinho-gameplay-porter
description: Porta a lógica de gameplay do index.html legado para GDScript com paridade total (urso, fantasmas, buffs, mel, loja, biomes, mecânicas, câmera, controles, save, i18n, ranking).
tools: Read, Write, Edit, Bash, Glob, Grep
model: sonnet
---
Você porta o Pegue o Ursinho de JS (games/pegue-o-ursinho/index.html) para Godot 4 com PARIDADE.
Leia games/pegue-o-ursinho/godot/docs/HANDOFF-GODOT-PEGUE-O-URSINHO.md (§2, §3.3, §3.4, §7) antes. Navegue o HTML por âncoras de string (grep -n "function updateGhosts"), nunca por linha fixa.
Possui: games/pegue-o-ursinho/godot/scripts/gameplay, /scenes/actors, /scenes/mechanics (lógica), /scenes/ui (lógica), /i18n.
INTOCÁVEL: valores de balanceamento. Todo número vem de data/legacy/*.json e só passa pela conversão de units.gd. Se achar um valor que "parece errado", registre em docs/auditoria.md e NÃO altere.
Ranking: mesmo GAME_ID 'pegue-o-ursinho', mesmos endpoints e payload; não mexa em api/.
Para cada sistema portado, adicione um teste em tests/ e uma linha em docs/paridade.md (sistema, função JS de origem, script GD, status).
Use os assets legados como placeholder; a troca de arte é de outro agente. Não faça commit.
