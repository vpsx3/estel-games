#!/usr/bin/env node
// Extrai dados puros do index.html legado para data/legacy/*.json.
// Sem dependencias. Localiza cada `const NOME=` por ancora de string (nunca por numero de linha),
// recorta o literal ate o fechamento balanceado e avalia em `vm` isolado.
// Uso: node tools/extract_legacy_data.mjs   (a partir de qualquer pasta)
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const GODOT_DIR = path.resolve(HERE, '..');
const HTML = path.resolve(GODOT_DIR, '..', 'index.html');
const OUT = path.join(GODOT_DIR, 'data', 'legacy');

const src = fs.readFileSync(HTML, 'utf8');

// ---- scanner: avanca por JS respeitando strings, template literals e comentarios ----
function skipString(s, i) { // s[i] e aspa simples ou dupla
  const q = s[i]; i++;
  while (i < s.length) {
    if (s[i] === '\\') { i += 2; continue; }
    if (s[i] === q) return i + 1;
    i++;
  }
  throw new Error('string nao fechada');
}
function skipTemplate(s, i) { // s[i] === crase
  i++;
  while (i < s.length) {
    if (s[i] === '\\') { i += 2; continue; }
    if (s[i] === '`') return i + 1;
    if (s[i] === '$' && s[i + 1] === '{') {
      i += 2; let d = 1;
      while (i < s.length && d > 0) {
        const c = s[i];
        if (c === '"' || c === "'") { i = skipString(s, i); continue; }
        if (c === '`') { i = skipTemplate(s, i); continue; }
        if (c === '{') d++;
        else if (c === '}') d--;
        i++;
      }
      continue;
    }
    i++;
  }
  throw new Error('template nao fechado');
}
// Le um statement a partir de `start` ate o `;` de profundidade 0. Retorna {end, commas}.
function scanStatement(s, start) {
  let i = start, depth = 0; const commas = [];
  while (i < s.length) {
    const c = s[i], n = s[i + 1];
    if (c === '"' || c === "'") { i = skipString(s, i); continue; }
    if (c === '`') { i = skipTemplate(s, i); continue; }
    if (c === '/' && n === '/') { while (i < s.length && s[i] !== '\n') i++; continue; }
    if (c === '/' && n === '*') { i = s.indexOf('*/', i + 2) + 2; continue; }
    if (c === '(' || c === '[' || c === '{') depth++;
    else if (c === ')' || c === ']' || c === '}') depth--;
    else if (c === ',' && depth === 0) commas.push(i);
    else if (c === ';' && depth === 0) return { end: i + 1, commas };
    i++;
  }
  throw new Error('statement sem ; a partir de ' + start);
}

// ---- coleta statements `const` de nivel zero (coluna 0) + ancoras extras ----
const statements = []; // {names, code, start}
function addStatement(start) {
  const { end, commas } = scanStatement(src, start);
  const code = src.slice(start, end);
  const cuts = [start + 'const'.length, ...commas.map(c => c + 1)];
  const bounds = [...cuts, end];
  const names = [];
  for (let k = 0; k < cuts.length; k++) {
    const piece = src.slice(bounds[k], bounds[k + 1]);
    const m = /^\s*([A-Za-z_$][\w$]*)\s*=/.exec(piece);
    if (m) names.push(m[1]);
  }
  statements.push({ names, code, start });
}
for (const m of src.matchAll(/^const\s/gm)) addStatement(m.index);
// ancoras extras (const no meio de uma linha)
for (const name of ['JOY_RADIUS']) {
  if (statements.some(s => s.names.includes(name))) continue;
  const idx = src.indexOf('const ' + name + '=');
  if (idx < 0) throw new Error('ancora nao encontrada: const ' + name);
  addStatement(idx);
}
statements.sort((a, b) => a.start - b.start);

// ---- avalia em contexto isolado, na ordem do arquivo ----
const ctx = vm.createContext({}, { codeGeneration: { strings: false, wasm: false } });
const values = {};   // nome -> valor (clonado via JSON)
const skipped = [];  // statements que dependem de DOM/ambiente
function hasFunction(v) {
  if (typeof v === 'function') return true;
  if (v && typeof v === 'object') return Object.values(v).some(hasFunction);
  return false;
}
for (const st of statements) {
  try {
    vm.runInContext(st.code, ctx, { timeout: 2000 });
  } catch (e) {
    skipped.push(`${st.names.join(', ')} (${e.constructor.name}: ${String(e.message).slice(0, 60)})`);
    continue;
  }
  for (const n of st.names) {
    const v = vm.runInContext(n, ctx);
    if (hasFunction(v)) { skipped.push(`${n} (contem funcao)`); continue; }
    values[n] = JSON.parse(JSON.stringify(v));
  }
}

function need(n) { if (!(n in values)) throw new Error('constante ausente/ilegivel: ' + n); return values[n]; }

// ---- monta saidas ----
const DEDICATED = new Set([
  'BIOME_MAPS', 'BIOMES', 'BIOME_MECH', 'GHOST_TYPES', 'MAP_BUFFS', 'ALL_BUFFS', 'ATTR_DEFS', 'ATTR_ORDER',
  'ATTR_EN', 'RAR_LABEL', 'MAP_FX_TEXT', 'STRINGS_GAME', 'BIOME_NAMES_EN', 'BUFF_EN', 'MAP_FX_EN',
  'mechTiles', 'joyVec', // estado de runtime (objetos vazios no load), nao sao dados
]);
const biomes = need('BIOMES').map(b => { const { MAP_TEMPLATE, ...rest } = b; return rest; });

const constants = {};
for (const st of statements) for (const n of st.names) {
  if (n in values && !DEDICATED.has(n)) constants[n] = values[n];
}
// Override Godot (nao altera o index.html legado): mundo dura 45s em vez de 120s. Aviso continua em BIOME_WARNING_TIME=10 (aos 35s).
constants.BIOME_DURATION = 45;

const strings = need('STRINGS_GAME');
const pt = {
  game: strings.pt,
  biome_names: Object.fromEntries(biomes.map(b => [String(b.id), b.name])),
  buffs: Object.fromEntries(need('MAP_BUFFS').map(b => [b.id, { name: b.name, desc: b.desc }])),
  map_fx: need('MAP_FX_TEXT'),
  attrs: Object.fromEntries(Object.entries(need('ATTR_DEFS')).map(([k, d]) => [k, d.name])),
  rarity: need('RAR_LABEL'),
};
const en = {
  game: strings.en,
  biome_names: need('BIOME_NAMES_EN'),
  buffs: need('BUFF_EN'),
  map_fx: need('MAP_FX_EN'),
  attrs: need('ATTR_EN'),
  rarity: { comum: strings.en.rar_comum, incomum: strings.en.rar_incomum, raro: strings.en.rar_raro },
};

const files = {
  'maps.json': need('BIOME_MAPS'),
  'biomes.json': biomes,
  'biome_mech.json': need('BIOME_MECH'),
  'ghost_types.json': need('GHOST_TYPES'),
  'buffs.json': {
    map_buffs: need('MAP_BUFFS'),
    fixed_intervals: need('FIXED_INTERVALS'),
    spray_slow_mult: need('SPRAY_SLOW_MULT'),
    spray_slow_dur: need('SPRAY_SLOW_DUR'),
    rarity_labels: need('RAR_LABEL'),
  },
  'attrs.json': { defs: need('ATTR_DEFS'), order: need('ATTR_ORDER') },
  'constants.json': constants,
  'strings_pt.json': pt,
  'strings_en.json': en,
};

function fmt(name, data) {
  let txt = JSON.stringify(data, null, 2);
  if (name === 'maps.json') { // cada linha de mapa em uma linha (continua JSON valido, diff legivel)
    txt = txt.replace(/\[\s*((?:[01],?\s*)+)\]/g, (_, body) => '[' + body.replace(/\s+/g, ' ').trim() + ']');
  }
  return txt + '\n';
}
fs.mkdirSync(OUT, { recursive: true });
for (const [name, data] of Object.entries(files)) {
  fs.writeFileSync(path.join(OUT, name), fmt(name, data));
}
console.log('OK ->', OUT);
for (const name of Object.keys(files)) console.log('  ' + name);
console.log('constants.json:', Object.keys(constants).length, 'chaves:', Object.keys(constants).join(', '));
console.log('ignorados (nao sao dados puros):', skipped.join(' | ') || '(nenhum)');
