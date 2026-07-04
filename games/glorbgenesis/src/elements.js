// Definição dos 13 elementos e a matriz declarativa de reações elemento×elemento.

export const E = {
  WOOD: 0, STONE: 1, GLASS: 2, FIRE: 3, WATER: 4, AIR: 5, LIGHTNING: 6,
  ICE: 7, POISON: 8, SLIME: 9, METAL: 10, GOLD: 11, DIAMOND: 12,
};

export const ELEMENTS = [
  { id: E.WOOD,      key: 'wood',      name: 'Madeira',  color: '#9a6a35', tags: ['orgânico', 'estrutural', 'inflamável'], rare: false, cooldown: 0 },
  { id: E.STONE,     key: 'stone',     name: 'Pedra',    color: '#8d8d96', tags: ['estrutural', 'pesado'],                 rare: false, cooldown: 0 },
  { id: E.GLASS,     key: 'glass',     name: 'Vidro',    color: '#a8dce8', tags: ['frágil', 'translúcido', 'cortante'],    rare: false, cooldown: 0 },
  { id: E.FIRE,      key: 'fire',      name: 'Fogo',     color: '#ff6a2a', tags: ['energia', 'destrutivo', 'volátil'],     rare: false, cooldown: 0 },
  { id: E.WATER,     key: 'water',     name: 'Água',     color: '#3f8cff', tags: ['fluido', 'vital'],                      rare: false, cooldown: 0 },
  { id: E.AIR,       key: 'air',       name: 'Ar',       color: '#c9e6e2', tags: ['fluido', 'leve', 'volátil'],            rare: false, cooldown: 0 },
  { id: E.LIGHTNING, key: 'lightning', name: 'Raio',     color: '#ffe94a', tags: ['energia', 'destrutivo', 'raro'],        rare: true,  cooldown: 2.5 },
  { id: E.ICE,       key: 'ice',       name: 'Gelo',     color: '#9fd8ff', tags: ['frio', 'frágil', 'lento'],              rare: false, cooldown: 0 },
  { id: E.POISON,    key: 'poison',    name: 'Veneno',   color: '#7dc832', tags: ['tóxico', 'corrosivo'],                  rare: false, cooldown: 0 },
  { id: E.SLIME,     key: 'slime',     name: 'Slime',    color: '#5fe07a', tags: ['orgânico', 'elástico', 'pegajoso'],     rare: false, cooldown: 0 },
  { id: E.METAL,     key: 'metal',     name: 'Metal',    color: '#b9c4d0', tags: ['estrutural', 'condutor', 'pesado'],     rare: false, cooldown: 0 },
  { id: E.GOLD,      key: 'gold',      name: 'Ouro',     color: '#ffc832', tags: ['precioso', 'maleável', 'condutor'],     rare: false, cooldown: 0 },
  { id: E.DIAMOND,   key: 'diamond',   name: 'Diamante', color: '#c8f4ff', tags: ['precioso', 'duríssimo', 'raro'],        rare: true,  cooldown: 3.5 },
];

export const FLAMMABLE = new Set([E.WOOD, E.SLIME]);
export const CONDUCTIVE = new Set([E.METAL, E.GOLD]);
export const STRUCTURAL = new Set([E.WOOD, E.STONE, E.METAL, E.GLASS, E.ICE, E.GOLD, E.DIAMOND]);

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

export function elemName(id) { return ELEMENTS[id].name; }
export function elemColor(id) { return ELEMENTS[id].color; }
