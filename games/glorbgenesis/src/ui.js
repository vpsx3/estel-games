// HUD, paleta de elementos (ícones desenhados em canvas), feed de eventos e inspetor.

import { ELEMENTS, E, elemName, elemColor } from './elements.js';
import { drawCreature } from './render.js';

let game = null;
let callbacks = null;
const el = {};
const paletteBtns = new Map();
let portraitCtx = null;
let inspectorTimer = 0;

export function initUI(g, cb) {
  game = g; callbacks = cb;
  for (const id of ['seedText', 'seedInput', 'btnNewWorld', 'pop', 'factions', 'worldTime',
    'palette', 'feed', 'inspector', 'brushSize', 'brushSizeVal', 'portrait']) {
    el[id] = document.getElementById(id);
  }
  portraitCtx = el.portrait.getContext('2d');
  buildPalette();

  document.querySelectorAll('.speedbtn').forEach(b => {
    b.addEventListener('click', () => {
      game.setSpeed(parseFloat(b.dataset.speed));
      document.querySelectorAll('.speedbtn').forEach(o => o.classList.toggle('active', o === b));
    });
  });
  el.btnNewWorld.addEventListener('click', () => callbacks.onNewWorld(el.seedInput.value.trim() || null));
  el.seedInput.addEventListener('keydown', e => {
    if (e.key === 'Enter') callbacks.onNewWorld(el.seedInput.value.trim() || null);
  });
  el.brushSize.addEventListener('input', () => {
    game.brush.radius = parseInt(el.brushSize.value, 10);
    el.brushSizeVal.textContent = el.brushSize.value;
  });
  document.getElementById('btnCloseInspector').addEventListener('click', () => selectCreature(null));
}

export function setGame(g) {
  game = g;
  el.seedText.textContent = `seed ${g.seedText}`;
  el.feed.innerHTML = '';
  selectCreature(null);
  selectTool('inspect');
  document.querySelectorAll('.speedbtn').forEach(o => o.classList.toggle('active', o.dataset.speed === '1'));
}

function buildPalette() {
  el.palette.innerHTML = '';
  paletteBtns.clear();

  const inspect = document.createElement('button');
  inspect.className = 'palbtn';
  inspect.title = 'Inspecionar criatura';
  inspect.appendChild(iconCanvas(-1));
  inspect.addEventListener('click', () => selectTool('inspect'));
  el.palette.appendChild(inspect);
  paletteBtns.set('inspect', inspect);

  for (const def of ELEMENTS) {
    const b = document.createElement('button');
    b.className = 'palbtn';
    b.title = def.name + (def.rare ? ' (cooldown)' : '');
    b.appendChild(iconCanvas(def.id));
    const cd = document.createElement('div');
    cd.className = 'cd';
    b.appendChild(cd);
    b.addEventListener('click', () => selectTool(def.id));
    el.palette.appendChild(b);
    paletteBtns.set(def.id, b);
  }
}

function selectTool(tool) {
  game.tool = tool;
  for (const [k, b] of paletteBtns) b.classList.toggle('active', k === tool);
}

// Ícones dos elementos gerados 100% em canvas
function iconCanvas(id) {
  const cv = document.createElement('canvas');
  cv.width = cv.height = 28;
  const c = cv.getContext('2d');
  const cx = 14, cy = 14;
  if (id === -1) { // lupa do inspetor
    c.strokeStyle = '#ddd'; c.lineWidth = 2.4;
    c.beginPath(); c.arc(12, 12, 6, 0, 7); c.stroke();
    c.beginPath(); c.moveTo(17, 17); c.lineTo(23, 23); c.stroke();
    return cv;
  }
  const col = elemColor(id);
  c.fillStyle = col; c.strokeStyle = col; c.lineWidth = 2;
  switch (id) {
    case E.WOOD:
      c.save(); c.translate(cx, cy); c.rotate(-0.5);
      c.fillRect(-9, -4, 18, 8);
      c.fillStyle = '#5a3a1a'; c.beginPath(); c.arc(-9, 0, 4, 0, 7); c.fill();
      c.restore(); break;
    case E.STONE:
      c.beginPath(); c.moveTo(5, 20); c.lineTo(8, 9); c.lineTo(15, 6); c.lineTo(22, 12); c.lineTo(20, 20);
      c.closePath(); c.fill(); break;
    case E.GLASS:
      c.globalAlpha = 0.5; c.fillRect(7, 6, 14, 16); c.globalAlpha = 1;
      c.strokeStyle = '#fff'; c.lineWidth = 1.4;
      c.beginPath(); c.moveTo(10, 19) ; c.lineTo(17, 8); c.stroke(); break;
    case E.FIRE:
      c.beginPath(); c.moveTo(9, 21); c.quadraticCurveTo(6, 12, 14, 5);
      c.quadraticCurveTo(14, 11, 19, 12); c.quadraticCurveTo(23, 17, 19, 21); c.closePath(); c.fill();
      c.fillStyle = '#ffe27a'; c.beginPath(); c.arc(14, 18, 3, 0, 7); c.fill(); break;
    case E.WATER:
      c.beginPath(); c.moveTo(14, 5); c.quadraticCurveTo(22, 15, 14, 22);
      c.quadraticCurveTo(6, 15, 14, 5); c.fill(); break;
    case E.AIR:
      c.lineWidth = 2.2;
      c.beginPath(); c.moveTo(5, 10); c.quadraticCurveTo(17, 6, 20, 11); c.stroke();
      c.beginPath(); c.moveTo(6, 16); c.quadraticCurveTo(19, 13, 22, 18); c.stroke(); break;
    case E.LIGHTNING:
      c.beginPath(); c.moveTo(16, 4); c.lineTo(9, 15); c.lineTo(14, 15); c.lineTo(11, 24);
      c.lineTo(20, 12); c.lineTo(15, 12); c.closePath(); c.fill(); break;
    case E.ICE:
      c.lineWidth = 2;
      for (let i = 0; i < 3; i++) {
        const a = i * Math.PI / 3;
        c.beginPath();
        c.moveTo(cx - Math.cos(a) * 9, cy - Math.sin(a) * 9);
        c.lineTo(cx + Math.cos(a) * 9, cy + Math.sin(a) * 9);
        c.stroke();
      }
      break;
    case E.POISON:
      c.beginPath(); c.moveTo(14, 6); c.quadraticCurveTo(21, 15, 14, 21);
      c.quadraticCurveTo(7, 15, 14, 6); c.fill();
      c.fillStyle = '#bff26a'; c.beginPath(); c.arc(12, 14, 1.7, 0, 7); c.arc(16, 17, 1.3, 0, 7); c.fill(); break;
    case E.SLIME:
      c.beginPath(); c.ellipse(cx, 16, 9, 7, 0, 0, 7); c.fill();
      c.fillStyle = '#15151c';
      c.beginPath(); c.arc(11, 14, 1.5, 0, 7); c.arc(17, 14, 1.5, 0, 7); c.fill(); break;
    case E.METAL:
      c.fillRect(6, 8, 16, 12);
      c.fillStyle = 'rgba(255,255,255,0.5)'; c.fillRect(6, 8, 16, 3);
      c.fillStyle = '#556'; c.fillRect(8, 16, 2, 2); c.fillRect(18, 16, 2, 2); break;
    case E.GOLD:
      c.beginPath(); c.arc(cx, cy, 8, 0, 7); c.fill();
      c.strokeStyle = '#fff2b0'; c.lineWidth = 1.5;
      c.beginPath(); c.arc(cx, cy, 5, 0, 7); c.stroke(); break;
    case E.DIAMOND:
      c.beginPath(); c.moveTo(14, 4); c.lineTo(22, 12); c.lineTo(14, 24); c.lineTo(6, 12);
      c.closePath(); c.fill();
      c.strokeStyle = '#fff'; c.lineWidth = 1;
      c.beginPath(); c.moveTo(10, 12); c.lineTo(14, 8); c.lineTo(18, 12); c.stroke(); break;
  }
  return cv;
}

export function pushFeed(msg, color) {
  const d = document.createElement('div');
  d.className = 'feeditem';
  d.style.borderLeftColor = color || '#888';
  d.textContent = msg;
  el.feed.prepend(d);
  while (el.feed.children.length > 8) el.feed.lastChild.remove();
  setTimeout(() => { d.classList.add('fading'); }, 9000);
  setTimeout(() => { d.remove(); }, 12000);
}

export function selectCreature(c) {
  game.selected = c;
  el.inspector.classList.toggle('hidden', !c);
  if (c) refreshInspector(true);
}

function refreshInspector(force) {
  const c = game.selected;
  if (!c) return;
  if (!c.alive) { selectCreature(null); return; }
  const mins = Math.floor(c.age / 60), secs = Math.floor(c.age % 60);
  document.getElementById('inspName').textContent = c.name + (c.isFirst ? ' ★ (o Primeiro)' : '');
  document.getElementById('inspAge').textContent = `idade ${mins}m${String(secs).padStart(2, '0')}s · ❤ ${Math.ceil(c.hp)}/${Math.ceil(c.stats.maxHp)}`;
  const f = document.getElementById('inspFaction');
  if (c.faction) { f.textContent = `⚑ ${c.faction.name}`; f.style.color = c.faction.color; }
  else { f.textContent = 'sem facção'; f.style.color = '#777'; }
  document.getElementById('inspStats').textContent =
    `vel ${c.stats.speed.toFixed(0)} · força ${c.attack.toFixed(1)} · def ${c.stats.defense.toFixed(1)}`
    + (c.weapon ? ` · ${c.weapon.name}` : '') + (c.vehicle ? ` · ${c.vehicle.name}` : '');
  const tr = document.getElementById('inspTraits');
  tr.innerHTML = '';
  if (c.traits.length === 0) tr.innerHTML = '<span class="dim">nenhum trait ainda</span>';
  for (const t of c.traits) {
    const s = document.createElement('span');
    s.className = 'trait';
    s.style.borderColor = elemColor(t.element);
    s.textContent = t.name;
    tr.appendChild(s);
  }
  const ab = document.getElementById('inspAbsorbed');
  const parts = [];
  for (const [k, v] of Object.entries(c.absorbed)) if (v > 0) parts.push(`${elemName(+k)} ×${v}`);
  ab.textContent = parts.length ? 'absorveu: ' + parts.join(', ') : 'não absorveu elementos';

  // retrato procedural ampliado
  const ctx = portraitCtx;
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.clearRect(0, 0, 110, 110);
  ctx.fillStyle = '#141821'; ctx.fillRect(0, 0, 110, 110);
  const scale = 42 / Math.max(8, c.bodyPlan.size + (c.bodyPlan.spikes ? 5 : 0));
  ctx.setTransform(scale, 0, 0, scale, 55 - c.x * scale, 62 - c.y * scale);
  drawCreature(ctx, c, performance.now() / 1000, true);
}

export function updateHUD() {
  el.pop.textContent = `pop ${game.creatures.length}`;
  el.factions.textContent = `facções ${game.factions.filter(f => f.members.length > 1).length}`;
  const m = Math.floor(game.time / 60), s = Math.floor(game.time % 60);
  el.worldTime.textContent = `${m}:${String(s).padStart(2, '0')}`;

  // cooldowns dos raros
  for (const def of ELEMENTS) {
    if (!def.rare) continue;
    const b = paletteBtns.get(def.id);
    const cd = b.querySelector('.cd');
    const rem = game.cooldowns[def.id] || 0;
    cd.style.height = rem > 0 ? `${(rem / def.cooldown) * 100}%` : '0%';
  }

  inspectorTimer -= 1;
  if (game.selected && inspectorTimer <= 0) { inspectorTimer = 6; refreshInspector(); }
}
