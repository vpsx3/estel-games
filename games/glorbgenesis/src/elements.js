// Definição dos 13 elementos e a matriz declarativa de reações elemento×elemento.

export const E = {
  WOOD: 0, STONE: 1, GLASS: 2, FIRE: 3, WATER: 4, AIR: 5, LIGHTNING: 6,
  ICE: 7, POISON: 8, SLIME: 9, METAL: 10, GOLD: 11, DIAMOND: 12,
  // Tier 2 (fusões)
  LAVA: 13, STEEL: 14, PLASMA: 15, SMOKE: 16, MUD: 17, MIST: 18, RUST: 19,
  SNOW: 20, GLACIER: 21, MAGNET: 22, STORM: 23, ACID: 24, SULFUR: 25,
  FUNGUS: 26, MOSS: 27, PRISM: 28, RELIC: 29,
  // Tier 3
  OBSIDIAN: 30, MIASMA: 31,
  CHARCOAL: 32, VAPOR: 33, BLIZZARD: 34, ASH: 35, SWAMP: 36, MERCURY: 37, ELECTRUM: 38,
  // Tier 4
  GUNPOWDER: 39, AURORA: 40, PLAGUE: 41, STARCORE: 42, ETHER: 43, MONOLITH: 44,
};

export const ELEMENTS = [
  { id: E.WOOD,      key: 'wood',      name: 'Madeira',  color: '#9a6a35', tags: ['orgânico', 'estrutural', 'inflamável'], rare: false, cooldown: 0,
    desc: 'Material de construção inflamável. Espalha floresta bem devagar em terreno plano.' },
  { id: E.STONE,     key: 'stone',     name: 'Pedra',    color: '#8d8d96', tags: ['estrutural', 'pesado'],                 rare: false, cooldown: 0,
    desc: 'Material sólido e pesado. Serve de abrigo: amortece o dano de quem luta ao lado dela.' },
  { id: E.GLASS,     key: 'glass',     name: 'Vidro',    color: '#a8dce8', tags: ['frágil', 'translúcido', 'cortante'],    rare: false, cooldown: 0,
    desc: 'Frágil e cortante: rende lâminas afiadas e refrata raios que o atingem.' },
  { id: E.FIRE,      key: 'fire',      name: 'Fogo',     color: '#ff6a2a', tags: ['energia', 'destrutivo', 'volátil'],     rare: false, cooldown: 0,
    desc: 'Queima criaturas e construções, espalha pela madeira e derrete gelo. Água o apaga.' },
  { id: E.WATER,     key: 'water',     name: 'Água',     color: '#3f8cff', tags: ['fluido', 'vital'],                      rare: false, cooldown: 0,
    desc: 'Apaga fogo e escorre um pouco antes de assentar. Ingrediente de muitas fusões.' },
  { id: E.AIR,       key: 'air',       name: 'Ar',       color: '#c9e6e2', tags: ['fluido', 'leve', 'volátil'],            rare: false, cooldown: 0,
    desc: 'Sopro passageiro que dissipa veneno. Base de fusões leves como fumaça, névoa e neve.' },
  { id: E.LIGHTNING, key: 'lightning', name: 'Raio',     color: '#ffe94a', tags: ['energia', 'destrutivo', 'raro'],        rare: true,  cooldown: 2.5,
    desc: 'Relâmpago que eletrocuta a área, percorre metais condutores e refrata em vidro e prisma.' },
  { id: E.ICE,       key: 'ice',       name: 'Gelo',     color: '#9fd8ff', tags: ['frio', 'frágil', 'lento'],              rare: false, cooldown: 0,
    desc: 'Piso escorregadio que congela a água ao redor. Fogo o derrete de volta em água.' },
  { id: E.POISON,    key: 'poison',    name: 'Veneno',   color: '#7dc832', tags: ['tóxico', 'corrosivo'],                  rare: false, cooldown: 0,
    desc: 'Envenena quem pisa nele e contamina a água. O ar o dissipa.' },
  { id: E.SLIME,     key: 'slime',     name: 'Slime',    color: '#5fe07a', tags: ['orgânico', 'elástico', 'pegajoso'],     rare: false, cooldown: 0,
    desc: 'Gosma pegajosa que atrasa quem passa por cima. Orgânica e inflamável.' },
  { id: E.METAL,     key: 'metal',     name: 'Metal',    color: '#b9c4d0', tags: ['estrutural', 'condutor', 'pesado'],     rare: false, cooldown: 0,
    desc: 'Material resistente e condutor: amplifica o dano de raios sobre ele.' },
  { id: E.GOLD,      key: 'gold',      name: 'Ouro',     color: '#ffc832', tags: ['precioso', 'maleável', 'condutor'],     rare: false, cooldown: 0,
    desc: 'Desperta cobiça: atrai as criaturas gananciosas da região e causa disputas.' },
  { id: E.DIAMOND,   key: 'diamond',   name: 'Diamante', color: '#c8f4ff', tags: ['precioso', 'duríssimo', 'raro'],        rare: true,  cooldown: 3.5,
    desc: 'O material mais duro: melhores construções e lâminas. Refrata raios.' },
  // Tier 2/3 — só existem via fusão (bloqueados na paleta até a descoberta)
  { id: E.LAVA,     key: 'lava',     name: 'Lava',       color: '#ff4a1a', tags: ['energia', 'destrutivo', 'fluido'],      rare: false, cooldown: 4, fused: true,
    desc: 'Derrete quem pisa e incendeia o que toca. Esfria virando pedra — ou vidro no deserto.' },
  { id: E.STEEL,    key: 'steel',    name: 'Aço',        color: '#8a99a8', tags: ['estrutural', 'condutor', 'pesado'],     rare: false, cooldown: 4, fused: true,
    desc: 'Liga estrutural mais resistente que o metal, mas ainda vulnerável à ferrugem.' },
  { id: E.PLASMA,   key: 'plasma',   name: 'Plasma',     color: '#ff4ae0', tags: ['energia', 'destrutivo', 'raro'],        rare: true,  cooldown: 8, fused: true,
    desc: 'Desintegra criaturas e depósitos vizinhos. Só obsidiana, diamante e monólito resistem.' },
  { id: E.SMOKE,    key: 'smoke',    name: 'Fumaça',     color: '#6a6a72', tags: ['fluido', 'volátil'],                    rare: false, cooldown: 4, fused: true,
    desc: 'Cega as criaturas dentro dela, que perdem o alvo de vista.' },
  { id: E.MUD,      key: 'mud',      name: 'Lama',       color: '#7a5a34', tags: ['fluido', 'fértil', 'lento'],            rare: false, cooldown: 4, fused: true,
    desc: 'Atola quem atravessa, reduzindo muito a velocidade. Fértil: pode brotar madeira.' },
  { id: E.MIST,     key: 'mist',     name: 'Névoa',      color: '#cfe2e6', tags: ['fluido', 'oculto'],                     rare: false, cooldown: 4, fused: true,
    desc: 'Oculta as criaturas dentro dela dos olhos de predadores.' },
  { id: E.RUST,     key: 'rust',     name: 'Ferrugem',   color: '#b0622a', tags: ['corrosivo'],                            rare: false, cooldown: 4, fused: true,
    desc: 'Corrói metal e aço vizinhos, inclusive construções, espalhando-se por eles.' },
  { id: E.SNOW,     key: 'snow',     name: 'Neve',       color: '#eef6ff', tags: ['frio', 'leve'],                         rare: false, cooldown: 4, fused: true,
    desc: 'Esfria o passo de quem atravessa e congela a água que toca.' },
  { id: E.GLACIER,  key: 'glacier',  name: 'Geleira',    color: '#86c4e8', tags: ['frio', 'estrutural'],                   rare: false, cooldown: 4, fused: true,
    desc: 'Gelo estrutural e liso: deslizar sobre ele é mais rápido que correr.' },
  { id: E.MAGNET,   key: 'magnet',   name: 'Ímã',        color: '#5060a0', tags: ['condutor', 'atrativo'],                 rare: false, cooldown: 4, fused: true,
    desc: 'Atrai criaturas metálicas e condutoras num raio ao redor.' },
  { id: E.STORM,    key: 'storm',    name: 'Tempestade', color: '#8f82e0', tags: ['energia', 'volátil'],                   rare: false, cooldown: 4, fused: true,
    desc: 'Nuvem carregada que dispara pequenos raios ao redor enquanto dura.' },
  { id: E.ACID,     key: 'acid',     name: 'Ácido',      color: '#c8e42a', tags: ['tóxico', 'corrosivo'],                  rare: false, cooldown: 4, fused: true,
    desc: 'Corrói criaturas e construções e dissolve pedra, metal e vidro próximos.' },
  { id: E.SULFUR,   key: 'sulfur',   name: 'Enxofre',    color: '#e6d44e', tags: ['tóxico', 'inflamável'],                 rare: false, cooldown: 4, fused: true,
    desc: 'Explode em chamas ao menor contato com fogo.' },
  { id: E.FUNGUS,   key: 'fungus',   name: 'Cogumelo',   color: '#c07ad0', tags: ['orgânico', 'mutagênico'],               rare: false, cooldown: 4, fused: true,
    desc: 'Mutagênico: quem para sobre ele pode ganhar uma mutação aleatória. Espalha devagar.' },
  { id: E.MOSS,     key: 'moss',     name: 'Musgo',      color: '#4f8f3c', tags: ['orgânico', 'vital'],                    rare: false, cooldown: 4, fused: true,
    desc: 'Tapete vivo que cura lentamente as criaturas que descansam sobre ele.' },
  { id: E.PRISM,    key: 'prism',    name: 'Prisma',     color: '#dcc4f4', tags: ['frágil', 'translúcido'],                rare: false, cooldown: 4, fused: true,
    desc: 'Refrata raios que o atingem em novos ramos, multiplicando a descarga.' },
  { id: E.RELIC,    key: 'relic',    name: 'Relíquia',   color: '#ffdf6a', tags: ['precioso', 'sagrado', 'raro'],          rare: true,  cooldown: 8, fused: true,
    desc: 'Atrai criaturas num raio amplo. Quem fica tempo demais por perto vira Devoto.' },
  { id: E.OBSIDIAN, key: 'obsidian', name: 'Obsidiana',  color: '#5a4a7a', tags: ['estrutural', 'duríssimo', 'raro'],      rare: true,  cooldown: 8, fused: true,
    desc: 'Rocha vulcânica duríssima: imune a ácido e plasma, excelente defesa.' },
  { id: E.MIASMA,   key: 'miasma',   name: 'Miasma',     color: '#8fae52', tags: ['tóxico', 'volátil', 'raro'],            rare: true,  cooldown: 8, fused: true,
    desc: 'Nuvem tóxica que consome as criaturas dentro dela e se alastra devagar.' },
  // Tier 3 (Spec 2)
  { id: E.CHARCOAL, key: 'charcoal', name: 'Carvão',     color: '#3a3a3a', tags: ['inflamável', 'combustível'],            rare: false, cooldown: 6, fused: true,
    desc: 'Combustível denso: aceso, queima 3× mais tempo que a madeira.' },
  { id: E.VAPOR,    key: 'vapor',    name: 'Vapor',      color: '#e8f0f2', tags: ['fluido', 'volátil'],                    rare: false, cooldown: 6, fused: true,
    desc: 'Nuvem quente que ofusca quem passa. Ao esfriar, condensa em névoa.' },
  { id: E.BLIZZARD, key: 'blizzard', name: 'Nevasca',    color: '#d8ecff', tags: ['frio', 'volátil'],                      rare: false, cooldown: 6, fused: true,
    desc: 'Congela e atrasa quem atravessa; deixa um manto de neve ao passar.' },
  { id: E.ASH,      key: 'ash',      name: 'Cinza',      color: '#7d7468', tags: ['fértil'],                               rare: false, cooldown: 6, fused: true,
    desc: 'Cinza fértil: pode brotar madeira ou musgo antes de assentar.' },
  { id: E.SWAMP,    key: 'swamp',    name: 'Pântano',    color: '#4a6a3a', tags: ['orgânico', 'tóxico', 'fértil'],         rare: false, cooldown: 6, fused: true,
    desc: 'Atola o passo, nutre criaturas orgânicas e envenena todas as outras.' },
  { id: E.MERCURY,  key: 'mercury',  name: 'Mercúrio',   color: '#b8c8d4', tags: ['condutor', 'fluido', 'tóxico'],         rare: false, cooldown: 6, fused: true,
    desc: 'Metal líquido que escorre como água, intoxica quem pisa e conduz raios.' },
  { id: E.ELECTRUM, key: 'electrum', name: 'Eletro',     color: '#ffe88a', tags: ['precioso', 'condutor'],                 rare: false, cooldown: 6, fused: true,
    desc: 'Brilha como tesouro e atrai criaturas — que levam choque ao pisar nele.' },
  // Tier 4 (Spec 2)
  { id: E.GUNPOWDER, key: 'gunpowder', name: 'Pólvora',        color: '#5a4a3a', tags: ['inflamável', 'explosivo', 'raro'], rare: true, cooldown: 8,  fused: true,
    desc: 'Detona numa grande explosão ao contato com fogo, lava ou raio.' },
  { id: E.AURORA,    key: 'aurora',    name: 'Aurora',         color: '#a0ffd8', tags: ['energia', 'sagrado', 'raro'],      rare: true, cooldown: 10, fused: true,
    desc: 'Luz que cura as criaturas num raio e ocasionalmente concede mutações benignas.' },
  { id: E.PLAGUE,    key: 'plague',    name: 'Praga',          color: '#6a7a2a', tags: ['tóxico', 'mutagênico', 'raro'],    rare: true, cooldown: 8,  fused: true,
    desc: 'Consome as criaturas e se alastra; os sobreviventes sofrem mutações sombrias.' },
  { id: E.STARCORE,  key: 'starcore',  name: 'Núcleo Estelar', color: '#ff9a3a', tags: ['energia', 'destrutivo', 'raro'],   rare: true, cooldown: 10, fused: true,
    desc: 'Puxa tudo com sua gravidade e incinera de perto. Colapsa numa explosão de obsidiana.' },
  { id: E.ETHER,     key: 'ether',     name: 'Éter',           color: '#d8ccff', tags: ['sagrado', 'oculto', 'raro'],       rare: true, cooldown: 10, fused: true,
    desc: 'Campo etéreo que cura e faz flutuar as criaturas ao redor.' },
  { id: E.MONOLITH,  key: 'monolith',  name: 'Monólito',       color: '#2a2a3a', tags: ['estrutural', 'sagrado', 'raro'],   rare: true, cooldown: 10, fused: true,
    desc: 'Indestrutível. Atrai criaturas solenemente e inspira facções a colecionar tesouros.' },
];

export const FLAMMABLE = new Set([E.WOOD, E.SLIME, E.SULFUR, E.FUNGUS, E.CHARCOAL, E.GUNPOWDER]);
export const CONDUCTIVE = new Set([E.METAL, E.GOLD, E.STEEL, E.MAGNET, E.MERCURY, E.ELECTRUM]);
export const STRUCTURAL = new Set([E.WOOD, E.STONE, E.METAL, E.GLASS, E.ICE, E.GOLD, E.DIAMOND, E.STEEL, E.GLACIER, E.OBSIDIAN, E.MONOLITH]);

// ---------------------------------------------------------------------------
// ENDGAME (Fase A): constantes de tuning centralizadas.
// ---------------------------------------------------------------------------
export const ENDGAME = {
  // Eras
  ERA_TRIBAL_MEMBERS: 8,       // 1ª facção com N membros → Era Tribal
  ERA_KINGDOMS_BUILDINGS: 12,  // 1ª facção com N construções → Era dos Reinos
  FACTION_CAP_BY_ERA: [24, 32, 32, 40], // cap de membros por era
  // Cataclismos
  CATA_MIN_ERA: 1,             // só a partir da Era Tribal
  CATA_INTERVAL: [420, 780],   // segundos de simulação entre eventos (sorteado)
  CATA_WARNING: 6,             // aviso no feed N segundos antes
  CATA_ERA_SCALE: 0.92,        // intervalo multiplicado por isso a cada era (mais frequente)
  // Território
  TERRITORY_REFRESH: 5,        // segundos entre repinturas do canvas de território
  TERRITORY_R_TOTEM: 7,        // raio de influência (tiles) por tipo
  TERRITORY_R_BUILDING: 3,
  TERRITORY_ALPHA: 0.16,
  // Guerras com desfecho
  WAR_SCORE_KILL: 3,
  WAR_SCORE_BUILDING: 2,
  WAR_DRAW_MARGIN: 4,          // |placar| ≤ margem → paz branca
  EXODUS_DIST: 90,             // tiles: distância mínima do êxodo
  // Gigantismo (permanente — nunca decai)
  GIANT_K: 0.055,              // sizeMul = min(MAX, 1 + sqrt(absorbLifetime) * K)
  GIANT_MAX_MUL: 2.6,
  GIANT_TIERS: [1.5, 2.0, 2.5],          // Graúdo, Colosso, Titã
  GIANT_TIER_NAMES: ['Graúdo', 'Colosso', 'Titã'],
  GIANT_HP_PER_TIER: 20,
  GIANT_STR_PER_TIER: 3,
  GIANT_SPEED_MUL_PER_TIER: 0.92,
  GIANT_SCARY_PER_TIER: 0.15,
  HUNT_MIN_TIER: 2,            // Caçadas a partir de Colosso
  HUNT_AGGR: 0.55,             // agressão média da facção para caçar
  TITAN_DROP_RADIUS: 4,        // tiles: raio da explosão elemental póstuma
  TITAN_DROP_MAX: 24,          // máximo de tiles semeados na morte
};

// ---------------------------------------------------------------------------
// Matriz declarativa de reações entre depósitos adjacentes.
// REACT[a] lista o que acontece quando um tile ativo do elemento `a`
// encontra um vizinho do elemento `b`:
//   { self, other } — novo elemento do próprio tile / do vizinho.
//   Valor -1 = remover depósito; undefined = sem mudança.
// Processada em world.envTick(). Fácil de estender: basta adicionar linhas.
// ---------------------------------------------------------------------------
export const REACT = {};
function r(a, b, self, other, desc) {
  (REACT[a] ||= {})[b] = { self, other, desc };
}

r(E.FIRE, E.WOOD, E.FIRE, E.FIRE, 'fogo se espalha pela madeira');
r(E.FIRE, E.SLIME, E.FIRE, E.FIRE, 'fogo queima slime');
r(E.FIRE, E.ICE, E.FIRE, E.WATER, 'fogo derrete gelo em água');
r(E.FIRE, E.WATER, -1, E.WATER, 'água evapora/apaga o fogo');
r(E.WATER, E.FIRE, E.WATER, -1, 'água apaga fogo');
r(E.WATER, E.POISON, E.POISON, E.POISON, 'veneno contamina a água');
r(E.POISON, E.WATER, E.POISON, E.POISON, 'veneno contamina a água');
r(E.AIR, E.POISON, E.AIR, -1, 'ar dissipa veneno');
r(E.ICE, E.WATER, E.ICE, E.ICE, 'gelo congela a água');
r(E.ICE, E.FIRE, E.WATER, E.FIRE, 'fogo derrete gelo');

// ---------------------------------------------------------------------------
// Fusões: quando tile ativo `a` encontra vizinho `b`, AMBOS viram o produto.
// Pares que já reagem na REACT (fogo×água, água×veneno) ficam de fora.
// ---------------------------------------------------------------------------
export const FUSE = {};
function fu(a, b, product) {
  (FUSE[a] ||= {})[b] = product;
  (FUSE[b] ||= {})[a] = product;
}
fu(E.FIRE, E.STONE, E.LAVA);
fu(E.FIRE, E.METAL, E.STEEL);
fu(E.FIRE, E.LIGHTNING, E.PLASMA);
fu(E.FIRE, E.AIR, E.SMOKE);
fu(E.WATER, E.STONE, E.MUD);
fu(E.WATER, E.AIR, E.MIST);
fu(E.WATER, E.METAL, E.RUST);
fu(E.ICE, E.AIR, E.SNOW);
fu(E.ICE, E.STONE, E.GLACIER);
fu(E.LIGHTNING, E.METAL, E.MAGNET);
fu(E.LIGHTNING, E.AIR, E.STORM);
fu(E.POISON, E.SLIME, E.ACID);
fu(E.POISON, E.STONE, E.SULFUR);
fu(E.WOOD, E.SLIME, E.FUNGUS);
fu(E.WOOD, E.WATER, E.MOSS);
fu(E.GLASS, E.LIGHTNING, E.PRISM);
fu(E.GOLD, E.DIAMOND, E.RELIC);
fu(E.LAVA, E.WATER, E.OBSIDIAN);   // Tier 3
fu(E.MIST, E.POISON, E.MIASMA);    // Tier 3
// Tier 3 — pelo menos um ingrediente Tier 2
fu(E.WOOD, E.SMOKE, E.CHARCOAL);
fu(E.LAVA, E.ICE, E.VAPOR);
fu(E.SNOW, E.STORM, E.BLIZZARD);
fu(E.LAVA, E.AIR, E.ASH);
fu(E.MUD, E.MOSS, E.SWAMP);
fu(E.STEEL, E.WATER, E.MERCURY);
fu(E.GOLD, E.STORM, E.ELECTRUM);
// Tier 4 — pelo menos um ingrediente Tier 3
fu(E.CHARCOAL, E.SULFUR, E.GUNPOWDER);
fu(E.BLIZZARD, E.PLASMA, E.AURORA);
fu(E.MIASMA, E.FUNGUS, E.PLAGUE);
fu(E.OBSIDIAN, E.PLASMA, E.STARCORE);
fu(E.VAPOR, E.RELIC, E.ETHER);
fu(E.OBSIDIAN, E.RELIC, E.MONOLITH);

export function elemName(id) { return ELEMENTS[id].name; }
export function elemColor(id) { return ELEMENTS[id].color; }

