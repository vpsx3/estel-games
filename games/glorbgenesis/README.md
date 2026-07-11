# Glorbgenesis

God-game sandbox procedural de elementos e bichinhos virtuais, em vanilla JavaScript + Canvas 2D.
Sem frameworks, sem backend, sem assets externos, sem persistência — cada mundo é efêmero e único.

Você é uma entidade divina: despeja **13 elementos básicos** no mundo, que se fundem em
**32 elementos avançados** (lava, aço, plasma, praga, monólito…) descobertos ao vivo, com
anúncio de conquista e desbloqueio permanente na paleta. Uma única criatura ("o Primeiro")
surge, se reproduz, absorve elementos e **evolui de forma aleatória e única por indivíduo**,
constrói vilas, funda facções, faz alianças e guerras. Nada é roteirizado — tudo emerge.

## Como jogar

**Basta abrir `index.html` num browser moderno.** Não precisa de servidor nem de build.

- **Paleta (esquerda)**: escolha um elemento e clique/arraste no mundo para despejar.
  Raio e Diamante são raros e têm cooldown. Ajuste o tamanho do pincel no slider.
- **Borracha**: apaga os depósitos de elementos da região do pincel e extingue
  chamas de construções.
- **Lupa**: modo inspecionar — clique numa criatura para ver nome, idade, traits,
  elementos absorvidos, facção e retrato ampliado do corpo procedural.
- **Câmera**: arraste com o botão direito (ou do meio) para mover, scroll para zoom.
- **Topo**: seed do mundo, população, facções, tempo, velocidade (pausa/1×/2×/4×) e
  **Novo Mundo** (aceita seed manual — mesma seed gera o mesmo mundo inicial e o mesmo Primeiro).
- **Feed (direita)**: narra nascimentos, evoluções, alianças, guerras e mortes.

Dicas divinas: fogo perto de uma vila de madeira gera tragédia; ouro no meio de uma multidão
gera ganância e guerra; raio num piso de metal se propaga em cadeia; dê diamante ao seu favorito.

## Estrutura do código

O código-fonte canônico são os ES modules em `/src`:

```
src/
  main.js       game loop, câmera, input, orquestração
  world.js      grid 192×192, terreno procedural (value noise), depósitos, tick ambiental
  elements.js   os 13 elementos + matriz declarativa de reações elemento×elemento
  creature.js   classe Creature: genome, corpo procedural, IA, combate, reprodução
  evolution.js  pools de mutação por elemento (absorção → trait único por indivíduo)
  building.js   construções procedurais: estruturas, objetos, armas, veículos
  society.js    encontros, facções, guerra/aliança que derivam com o tempo
  render.js     desenho de tudo (terreno, depósitos, construções, criaturas, partículas)
  ui.js         HUD, paleta (ícones em canvas), inspetor, feed de eventos
  rng.js        PRNG seedado (mulberry32) — Math.random() é proibido na simulação
  names.js      gerador procedural de nomes (criaturas e facções)
```

Browsers bloqueiam `import` de ES modules via `file://` (CORS), então o `index.html`
carrega um bundle inline gerado a partir de `/src` — por isso ele abre direto do disco.

### Desenvolvimento

1. Edite os módulos em `/src`.
2. Rode `node build.mjs` para regenerar o bundle inline do `index.html` (e o `dev.html`).
3. Alternativa sem rebuild: sirva a pasta (`python3 -m http.server`) e abra `dev.html`,
   que usa os ES modules diretamente.

## Performance

60 FPS com 200+ criaturas e centenas de construções: spatial hashing para proximidade,
culling de renderização fora da câmera, terreno pré-renderizado, cap populacional suave
(fertilidade cai com densidade local; teto de 220).
