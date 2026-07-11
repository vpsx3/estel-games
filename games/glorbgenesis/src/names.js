// Gerador procedural de nomes para criaturas e facções.

const ONSETS = ['Gl', 'Bl', 'Zr', 'Kr', 'M', 'F', 'Sn', 'Vr', 'T', 'Z', 'Pl', 'Gr', 'N', 'B', 'Squ', 'Dr', 'Y', 'Fl', 'Br', 'Qu'];
const VOWELS = ['o', 'a', 'e', 'i', 'u', 'oo', 'ee', 'ou', 'ie', 'ua'];
const MIDS = ['rb', 'lm', 'zz', 'mb', 'nk', 'rg', 'bl', 'p', 'g', 'd', 'lb', 'v', 'x', 'squ', 'rp'];
const ENDS = ['p', 'b', 'rp', 'sh', 'x', 'm', 'g', 'k', 'lo', 'ba', 'zo', 'ni', 'ti', 'lu', 'ra', ''];

export function creatureName(rng) {
  let n = rng.pick(ONSETS) + rng.pick(VOWELS);
  if (rng.chance(0.55)) n += rng.pick(MIDS) + rng.pick(VOWELS);
  n += rng.pick(ENDS);
  return n;
}

const FACTION_ROOTS = ['Brasa', 'Gelume', 'Vidral', 'Ferrume', 'Aurax', 'Limo', 'Petra', 'Ventania', 'Fulgor', 'Umbra', 'Toxina', 'Cintila', 'Rocha', 'Bruma', 'Chispa', 'Orvale', 'Gluma', 'Zarpa'];
const FACTION_SUFFIX = ['', ' Rubra', ' Antiga', ' Errante', ' Prima', ' do Norte', ' Voraz', ' Serena', ' Furiosa', ' Oculta', ' Dourada', ' Gelada'];

export function factionName(rng, used) {
  for (let i = 0; i < 40; i++) {
    const n = rng.pick(FACTION_ROOTS) + rng.pick(FACTION_SUFFIX);
    if (!used.has(n)) { used.add(n); return n; }
  }
  // fallback: nome sintético único
  const n = rng.pick(FACTION_ROOTS) + '-' + rng.int(10, 99);
  used.add(n);
  return n;
}

