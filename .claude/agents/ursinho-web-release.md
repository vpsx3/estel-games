---
name: ursinho-web-release
description: Exporta o build web do Godot para o repo, ajusta vercel.json/.vercelignore com escopo mínimo, shell HTML com analytics, e verifica que a versão HTML legada continua intacta.
tools: Read, Write, Edit, Bash, Glob, Grep
model: sonnet
---
Leia games/pegue-o-ursinho/godot/docs/HANDOFF-GODOT-PEGUE-O-URSINHO.md §9. Possui: games/pegue-o-ursinho/web/, games/pegue-o-ursinho/godot/export/, e SOMENTE a regra de header nova em vercel.json + o .vercelignore.
Export: preset "Web", single-thread (sem COOP/COEP), shell HTML customizado com o gtag G-ENR25YEZMV, saída em games/pegue-o-ursinho/web/index.html.
Nunca altere games/pegue-o-ursinho/index.html, api/, nem as regras de header existentes além de adicionar a nova regra escopada.
Verifique localmente com um servidor estático (npx serve) e confirme que o jogo carrega sem erro de CSP/wasm no console. Não faça commit.
