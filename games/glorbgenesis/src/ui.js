// HUD, paleta de elementos (ícones desenhados em canvas), feed de eventos e inspetor.

import { ELEMENTS, E, ENDGAME, elemName, elemColor } from './elements.js';
import { ELEMENT_GIFTS } from './evolution.js';
import { ERAS } from './society.js';
import { drawCreature } from './render.js';
let game = null;
let callbacks = null;
const el = {};
const paletteBtns = new Map();
let portraitCtx = null;
let inspectorTimer = 0;
let lockedFeedAt = -Infinity;
let legendTimer = 0;
let legendHtml = '';

export function initUI(g, cb) {
  game = g; callbacks = cb;
  for (const id of ['topbar', 'seedText', 'seedInput', 'btnNewWorld', 'pop', 'factions', 'worldTime', 'eraLabel', 'eraBanner',
    'palette', 'palTip', 'feed', 'feedTab', 'inspector', 'brushSize', 'brushSizeVal', 'portrait', 'lensBtn', 'lensLegend',
    'discovery', 'discoveryIcon', 'discoveryName', 'discoveryDesc']) {
    el[id] = document.getElementById(id);
  }
  // selo de devoração: só aparece quando os glorbs limpam o excesso do mapa
  if (el.topbar && !el.purgeBadge) {
    const badge = document.createElement('span');
    badge.className = 'stat';
    badge.id = 'purgeBadge';
    badge.style.display = 'none';
    badge.style.color = '#b6f0ff';
    el.topbar.appendChild(badge);
    el.purgeBadge = badge;
  }
  el.feedTab.addEventListener('click', () => setFeedOpen(!feedOpen));
  // tocar fora da paleta esconde o tooltip de elemento
  document.addEventListener('pointerdown', e => {
    if (!(e.target.closest && e.target.closest('.palbtn'))) hidePalTip();
  }, { passive: true });
  portraitCtx = el.portrait.getContext('2d');
  buildPalette();
  game.onDiscover = id => { unlockPaletteBtn(id); showDiscoveryBanner(id); };

  document.querySelectorAll('.speedbtn[data-speed]').forEach(b => {
    b.addEventListener('click', () => {
      game.setSpeed(parseFloat(b.dataset.speed));
      document.querySelectorAll('.speedbtn[data-speed]').forEach(o => o.classList.toggle('active', o === b));
    });
  });
  el.lensBtn.addEventListener('click', () => {
    game.lensFactions = !game.lensFactions;
    el.lensBtn.classList.toggle('active', game.lensFactions);
  });
  el.btnNewWorld.addEventListener('click', () => callbacks.onNewWorld(el.seedInput.value.trim() || null));
  el.seedInput.addEventListener('keydown', e => {
    if (e.key === 'Enter') callbacks.onNewWorld(el.seedInput.value.trim() || null);
  });
  el.brushSize.addEventListener('input', () => {
    game.brush.radius = parseInt(el.brushSize.value, 10);
    el.brushSizeVal.textContent = el.brushSize.value;
  });
  document.getElementById('btnCloseInspector').addEventListener('click', () => { selectCreature(null); selectBuilding(null); });

  // botões de câmera: seguir a criatura selecionada e recentralizar
  if (el.topbar && !el.followBtn) {
    const followBtn = document.createElement('button');
    followBtn.className = 'speedbtn';
    followBtn.id = 'followBtn';
    followBtn.title = 'Seguir a criatura selecionada';
    followBtn.textContent = '🎯';
    followBtn.addEventListener('click', () => {
      const on = callbacks.onToggleFollow && callbacks.onToggleFollow();
      followBtn.classList.toggle('active', !!on);
    });
    const recenterBtn = document.createElement('button');
    recenterBtn.className = 'speedbtn';
    recenterBtn.title = 'Centralizar na criatura';
    recenterBtn.textContent = '⌖';
    recenterBtn.addEventListener('click', () => callbacks.onRecenter && callbacks.onRecenter());
    el.topbar.appendChild(followBtn);
    el.topbar.appendChild(recenterBtn);
    el.followBtn = followBtn;
  }
}

// Sincroniza o botão 🎯 quando o seguir liga/desliga (inclusive automaticamente).
export function setFollowActive(on) {
  if (el.followBtn) el.followBtn.classList.toggle('active', !!on);
}

export function setGame(g) {
  game = g;
  el.seedText.textContent = `seed ${g.seedText}`;
  el.feed.innerHTML = '';
  feedUnread = 0;
  updateFeedTab();
  buildPalette(); // reconstrói respeitando game.discovered
  game.onDiscover = id => { unlockPaletteBtn(id); showDiscoveryBanner(id); };
  selectBuilding(null);
  selectCreature(null);
  selectTool('inspect');
  el.eraBanner.classList.remove('show');
  el.discovery.classList.remove('show');
  discoveryQueue.length = 0;
  el.lensBtn.classList.remove('active');
  document.querySelectorAll('.speedbtn[data-speed]').forEach(o => o.classList.toggle('active', o.dataset.speed === '1'));
}

function buildPalette() {
  el.palette.innerHTML = '';
  paletteBtns.clear();

  const inspect = document.createElement('button');
  inspect.className = 'palbtn';
  inspect.setAttribute('aria-label', 'Lupa');
  inspect.appendChild(iconCanvas(-1));
  inspect.addEventListener('click', () => selectTool('inspect'));
  attachPalTip(inspect, { name: 'Lupa', desc: 'Inspeciona criaturas e construções: toque numa para ver seus detalhes.' });
  el.palette.appendChild(inspect);
  paletteBtns.set('inspect', inspect);

  const eraser = document.createElement('button');
  eraser.className = 'palbtn';
  eraser.setAttribute('aria-label', 'Borracha');
  eraser.appendChild(iconCanvas(-2));
  eraser.addEventListener('click', () => selectTool('erase'));
  attachPalTip(eraser, { name: 'Borracha', desc: 'Apaga os depósitos de elementos na região do pincel e extingue chamas de construções.' });
  el.palette.appendChild(eraser);
  paletteBtns.set('erase', eraser);

  for (const def of ELEMENTS) {
    const b = document.createElement('button');
    b.className = 'palbtn';
    const locked = def.fused && !game.discovered.has(def.id);
    if (locked) {
      b.classList.add('locked');
      b.setAttribute('aria-label', '???');
      b.appendChild(lockedIcon());
    } else {
      b.setAttribute('aria-label', def.name);
      b.appendChild(iconCanvas(def.id));
    }
    const cd = document.createElement('div');
    cd.className = 'cd';
    b.appendChild(cd);
    b.addEventListener('click', () => {
      if (b.classList.contains('locked')) {
        const now = performance.now();
        if (now - lockedFeedAt > 2000) {
          lockedFeedAt = now;
          pushFeed('🔒 Descubra este elemento fundindo outros dois', '#888');
        }
        return;
      }
      selectTool(def.id);
    });
    attachPalTip(b, def);
    el.palette.appendChild(b);
    paletteBtns.set(def.id, b);
  }
}

// Tooltip da paleta: hover no desktop, dedo pressionado no touch.
// Lê o estado do botão na hora de exibir (elementos destravam ao vivo).
let palTipHideTimer = 0;
function attachPalTip(btn, def) {
  const show = () => {
    clearTimeout(palTipHideTimer);
    const locked = btn.classList.contains('locked');
    el.palTip.innerHTML = '';
    const name = document.createElement('b');
    name.textContent = locked ? '???' : def.name + (def.rare ? ' · recarga lenta' : '');
    if (!locked && def.color) name.style.color = def.color;
    const desc = document.createElement('div');
    desc.className = 'desc';
    desc.textContent = locked ? 'Elemento oculto: descubra-o fundindo outros dois no mundo.' : def.desc;
    el.palTip.append(name, desc);
    el.palTip.classList.remove('hidden');
    const r = btn.getBoundingClientRect();
    el.palTip.style.left = Math.min(r.right + 8, window.innerWidth - el.palTip.offsetWidth - 8) + 'px';
    el.palTip.style.top = Math.max(8, Math.min(window.innerHeight - el.palTip.offsetHeight - 8,
      r.top + r.height / 2 - el.palTip.offsetHeight / 2)) + 'px';
  };
  btn.addEventListener('pointerenter', e => { if (e.pointerType === 'mouse') show(); });
  btn.addEventListener('pointerleave', e => { if (e.pointerType === 'mouse') hidePalTip(); });
  // touch: mostra enquanto o dedo pressiona e segura mais um pouco para ler
  btn.addEventListener('pointerdown', e => { if (e.pointerType !== 'mouse') show(); });
  for (const ev of ['pointerup', 'pointercancel']) {
    btn.addEventListener(ev, e => {
      if (e.pointerType === 'mouse') return;
      clearTimeout(palTipHideTimer);
      palTipHideTimer = setTimeout(hidePalTip, 2500);
    });
  }
  // touch: selecionar o elemento (tap) também mostra o tooltip — caminho
  // garantido mesmo onde o navegador engole o pointerdown (scroll da paleta)
  btn.addEventListener('click', () => {
    if (!matchMedia('(pointer: coarse)').matches) return;
    show();
    clearTimeout(palTipHideTimer);
    palTipHideTimer = setTimeout(hidePalTip, 2500);
  });
}
function hidePalTip() { el.palTip.classList.add('hidden'); }

// Ícone "?" dos elementos ainda não descobertos
function lockedIcon() {
  const cv = document.createElement('canvas');
  cv.width = cv.height = 28;
  const c = cv.getContext('2d');
  c.fillStyle = '#666';
  c.font = 'bold 16px "Segoe UI", system-ui, sans-serif';
  c.textAlign = 'center'; c.textBaseline = 'middle';
  c.fillText('?', 14, 15);
  return cv;
}

// Desbloqueio ao vivo quando uma fusão é descoberta
function unlockPaletteBtn(id) {
  const b = paletteBtns.get(id);
  if (!b || !b.classList.contains('locked')) return;
  b.classList.remove('locked');
  b.setAttribute('aria-label', ELEMENTS[id].name);
  b.querySelector('canvas').replaceWith(iconCanvas(id));
}

export function selectTool(tool) {
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
  if (id === -2) { // borracha
    c.save(); c.translate(cx, cy + 1); c.rotate(-0.6);
    c.fillStyle = '#e07a9a'; c.fillRect(-8, -5, 9, 10);   // ponta rosa
    c.fillStyle = '#d5d8e0'; c.fillRect(1, -5, 8, 10);    // corpo claro
    c.restore();
    c.strokeStyle = '#8a93a8'; c.lineWidth = 1.6;
    c.beginPath(); c.moveTo(6, 24); c.lineTo(20, 24); c.stroke(); // traço apagado
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
    case E.LAVA:
      c.beginPath(); c.moveTo(14, 5); c.quadraticCurveTo(22, 15, 14, 22);
      c.quadraticCurveTo(6, 15, 14, 5); c.fill();
      c.fillStyle = '#ffe27a'; c.beginPath(); c.arc(14, 15, 3, 0, 7); c.fill(); break;
    case E.STEEL:
      c.fillRect(6, 9, 16, 10);
      c.strokeStyle = '#fff'; c.lineWidth = 1;
      c.beginPath(); c.moveTo(6, 12.5); c.lineTo(22, 12.5); c.moveTo(6, 15.5); c.lineTo(22, 15.5); c.stroke(); break;
    case E.PLASMA:
      c.beginPath(); c.arc(cx, cy, 7, 0, 7); c.fill();
      c.beginPath();
      for (const [dx, dy] of [[1, 1], [1, -1], [-1, 1], [-1, -1]]) {
        c.moveTo(cx + dx * 8, cy + dy * 8); c.lineTo(cx + dx * 11, cy + dy * 11);
      }
      c.stroke(); break;
    case E.SMOKE:
      c.globalAlpha = 0.6;
      c.beginPath(); c.arc(10, 19, 4.5, 0, 7); c.fill();
      c.beginPath(); c.arc(14, 13, 4.5, 0, 7); c.fill();
      c.beginPath(); c.arc(18, 7, 4, 0, 7); c.fill();
      c.globalAlpha = 1; break;
    case E.MUD:
      c.beginPath(); c.ellipse(cx, 19, 9, 4, 0, 0, 7); c.fill();
      c.beginPath(); c.arc(11, 13, 1.8, 0, 7); c.arc(17, 11, 1.4, 0, 7); c.fill(); break;
    case E.MIST:
      c.globalAlpha = 0.7; c.lineWidth = 2;
      for (let i = 0; i < 3; i++) {
        const y = 9 + i * 5;
        c.beginPath(); c.moveTo(5, y); c.quadraticCurveTo(10, y - 3, 14, y); c.quadraticCurveTo(18, y + 3, 23, y); c.stroke();
      }
      c.globalAlpha = 1; break;
    case E.RUST:
      c.save(); c.translate(cx, cy); c.rotate(0.3);
      c.fillRect(-6, -6, 12, 12);
      c.globalCompositeOperation = 'destination-out';
      for (const [dx, dy] of [[-6, -6], [6, -6], [-6, 6], [6, 6]]) {
        c.beginPath(); c.arc(dx, dy, 2.5, 0, 7); c.fill();
      }
      c.globalCompositeOperation = 'source-over';
      c.restore(); break;
    case E.SNOW:
      c.lineWidth = 2;
      for (let i = 0; i < 3; i++) {
        const a = i * Math.PI / 3 + Math.PI / 6;
        c.beginPath();
        c.moveTo(cx - Math.cos(a) * 8, cy - Math.sin(a) * 8);
        c.lineTo(cx + Math.cos(a) * 8, cy + Math.sin(a) * 8);
        c.stroke();
      }
      break;
    case E.GLACIER:
      c.beginPath(); c.moveTo(4, 20); c.lineTo(11, 7); c.lineTo(16, 13); c.lineTo(20, 9); c.lineTo(24, 20);
      c.closePath(); c.fill();
      c.strokeStyle = '#3f8cff'; c.lineWidth = 1.5;
      c.beginPath(); c.moveTo(3, 21); c.lineTo(25, 21); c.stroke(); break;
    case E.MAGNET:
      c.lineWidth = 4;
      c.beginPath(); c.arc(cx, 12, 7, Math.PI, 0); c.stroke();
      c.beginPath(); c.moveTo(7, 12); c.lineTo(7, 20); c.moveTo(21, 12); c.lineTo(21, 20); c.stroke();
      c.strokeStyle = '#d0d8ff';
      c.beginPath(); c.moveTo(7, 17); c.lineTo(7, 21); c.moveTo(21, 17); c.lineTo(21, 21); c.stroke(); break;
    case E.STORM:
      c.beginPath(); c.arc(11, 10, 5, 0, 7); c.fill();
      c.beginPath(); c.arc(17, 9, 4.5, 0, 7); c.fill();
      c.fillRect(7, 9, 14, 5);
      c.fillStyle = '#ffe94a';
      c.beginPath(); c.moveTo(15, 15); c.lineTo(11, 20); c.lineTo(14, 20); c.lineTo(11, 25);
      c.lineTo(17, 19); c.lineTo(14, 19); c.closePath(); c.fill(); break;
    case E.ACID:
      c.beginPath(); c.moveTo(14, 5); c.quadraticCurveTo(22, 15, 14, 22);
      c.quadraticCurveTo(6, 15, 14, 5); c.fill();
      c.strokeStyle = '#0b0d12'; c.lineWidth = 1.2;
      c.beginPath(); c.arc(12, 13, 1.8, 0, 7); c.stroke();
      c.beginPath(); c.arc(16, 16, 1.4, 0, 7); c.stroke(); break;
    case E.SULFUR:
      c.beginPath(); c.moveTo(cx, 5); c.lineTo(23, cy); c.lineTo(cx, 23); c.lineTo(5, cy);
      c.closePath(); c.fill();
      c.fillStyle = '#7a6a1a'; c.beginPath(); c.arc(cx, cy, 2.2, 0, 7); c.fill(); break;
    case E.FUNGUS:
      c.beginPath(); c.arc(cx, 13, 8, Math.PI, 0); c.closePath(); c.fill();
      c.fillStyle = '#e8d8f0'; c.fillRect(11.5, 13, 5, 9); break;
    case E.MOSS:
      for (const [mx, mr] of [[8, 4], [14, 4.5], [20, 4]]) {
        c.beginPath(); c.arc(mx, 19, mr, Math.PI, 0); c.closePath(); c.fill();
      }
      break;
    case E.PRISM:
      c.lineWidth = 2;
      c.beginPath(); c.moveTo(14, 6); c.lineTo(23, 21); c.lineTo(5, 21); c.closePath(); c.stroke();
      c.strokeStyle = '#fff'; c.lineWidth = 1.2;
      c.beginPath(); c.moveTo(11, 17); c.lineTo(17, 11); c.stroke(); break;
    case E.RELIC:
      c.beginPath();
      c.moveTo(cx, 5); c.quadraticCurveTo(cx + 2, cy - 2, 23, cy); c.quadraticCurveTo(cx + 2, cy + 2, cx, 23);
      c.quadraticCurveTo(cx - 2, cy + 2, 5, cy); c.quadraticCurveTo(cx - 2, cy - 2, cx, 5);
      c.fill();
      c.lineWidth = 1.5;
      c.beginPath(); c.arc(cx, cy, 11, 0, 7); c.stroke(); break;
    case E.OBSIDIAN:
      c.beginPath(); c.moveTo(cx, 4); c.lineTo(20, cy); c.lineTo(cx, 24); c.lineTo(8, cy);
      c.closePath(); c.fill();
      c.strokeStyle = 'rgba(255,255,255,0.35)'; c.lineWidth = 1;
      c.beginPath(); c.moveTo(cx, 4); c.lineTo(cx, 24); c.stroke();
      c.fillStyle = '#fff'; c.fillRect(13, 6, 2, 3); break;
    case E.MIASMA:
      c.globalAlpha = 0.55;
      c.beginPath(); c.arc(10, 16, 5, 0, 7); c.fill();
      c.beginPath(); c.arc(17, 13, 5.5, 0, 7); c.fill();
      c.beginPath(); c.arc(13, 9, 4, 0, 7); c.fill();
      c.globalAlpha = 1;
      c.fillStyle = '#3a4a1a';
      c.beginPath(); c.arc(11, 15, 1.2, 0, 7); c.arc(17, 12, 1.2, 0, 7); c.arc(14, 19, 1.2, 0, 7); c.fill(); break;
    case E.CHARCOAL: // 3 quadrados irregulares empilhados
      for (const [qx, qy, rot] of [[10, 15, 0.15], [16, 14, -0.2], [13, 8, 0.1]]) {
        c.save(); c.translate(qx, qy); c.rotate(rot); c.fillRect(-4, -4, 8, 8); c.restore();
      }
      break;
    case E.VAPOR: // 3 ondas verticais em S subindo
      c.globalAlpha = 0.8; c.lineWidth = 2;
      for (let i = 0; i < 3; i++) {
        const x = 8 + i * 6;
        c.beginPath(); c.moveTo(x, 23);
        c.quadraticCurveTo(x - 3, 17, x, 13); c.quadraticCurveTo(x + 3, 9, x, 5);
        c.stroke();
      }
      c.globalAlpha = 1; break;
    case E.BLIZZARD: // asterisco de neve de 6 pontas + traços de vento
      c.lineWidth = 2;
      for (let i = 0; i < 3; i++) {
        const a = i * Math.PI / 3;
        c.beginPath();
        c.moveTo(17 - Math.cos(a) * 7, cy - Math.sin(a) * 7);
        c.lineTo(17 + Math.cos(a) * 7, cy + Math.sin(a) * 7);
        c.stroke();
      }
      c.lineWidth = 1.6;
      c.beginPath(); c.moveTo(3, 9); c.lineTo(9, 12); c.moveTo(3, 17); c.lineTo(9, 19); c.stroke();
      break;
    case E.ASH: // montinho com pontinhos acima
      c.beginPath(); c.ellipse(cx, 19, 9, 5, 0, Math.PI, 0); c.closePath(); c.fill();
      c.beginPath();
      c.arc(9, 10, 1.1, 0, 7); c.arc(14, 7, 1.1, 0, 7); c.arc(18, 10, 1.1, 0, 7); c.arc(12, 12, 1.1, 0, 7);
      c.fill(); break;
    case E.SWAMP: // elipse d'água com juncos
      c.globalAlpha = 0.8;
      c.beginPath(); c.ellipse(cx, 18, 9, 4.5, 0, 0, 7); c.fill();
      c.globalAlpha = 1; c.lineWidth = 2;
      c.beginPath(); c.moveTo(11, 17); c.lineTo(11, 6); c.moveTo(17, 17); c.lineTo(17, 8); c.stroke();
      break;
    case E.MERCURY: // gota com brilho branco à esquerda
      c.beginPath(); c.moveTo(14, 5); c.quadraticCurveTo(22, 15, 14, 22);
      c.quadraticCurveTo(6, 15, 14, 5); c.fill();
      c.strokeStyle = '#fff'; c.lineWidth = 1.6;
      c.beginPath(); c.arc(14, 14, 5, Math.PI * 0.75, Math.PI * 1.35); c.stroke();
      break;
    case E.ELECTRUM: // moeda com mini-raio interno
      c.beginPath(); c.arc(cx, cy, 8, 0, 7); c.fill();
      c.fillStyle = '#7a5a00';
      c.beginPath(); c.moveTo(15, 8); c.lineTo(11, 14); c.lineTo(14, 14); c.lineTo(12, 20);
      c.lineTo(17, 13); c.lineTo(14, 13); c.closePath(); c.fill();
      break;
    case E.GUNPOWDER: // círculo com pavio e pontinhos na base
      c.beginPath(); c.arc(cx, 16, 7, 0, 7); c.fill();
      c.lineWidth = 1.6;
      c.beginPath(); c.moveTo(14, 9); c.quadraticCurveTo(17, 6, 21, 6); c.stroke();
      c.beginPath(); c.arc(6, 23, 1.1, 0, 7); c.arc(14, 25, 1.1, 0, 7); c.arc(22, 23, 1.1, 0, 7); c.fill();
      break;
    case E.PLAGUE: // círculo irregular com bolhas escuras
      c.beginPath();
      for (let i = 0; i <= 12; i++) {
        const a = (i / 12) * Math.PI * 2;
        const r = 8 + 1.6 * Math.sin(a * 3 + 0.7);
        const x = cx + Math.cos(a) * r, y = cy + Math.sin(a) * r;
        i ? c.lineTo(x, y) : c.moveTo(x, y);
      }
      c.closePath(); c.fill();
      c.fillStyle = '#3a4a12';
      c.beginPath(); c.arc(11, 12, 1.8, 0, 7); c.arc(17, 15, 1.5, 0, 7); c.arc(13, 18, 1.3, 0, 7); c.fill();
      break;
    case E.AURORA: // 3 faixas onduladas verticais
      for (let i = 0; i < 3; i++) {
        c.globalAlpha = [1, 0.7, 0.4][i];
        const x = 8 + i * 6;
        c.beginPath();
        c.moveTo(x - 2, 4);
        c.quadraticCurveTo(x + 3, 10, x - 2, 16); c.quadraticCurveTo(x - 5, 20, x - 2, 24);
        c.lineTo(x + 2, 24);
        c.quadraticCurveTo(x - 1, 20, x + 2, 16); c.quadraticCurveTo(x + 7, 10, x + 2, 4);
        c.closePath(); c.fill();
      }
      c.globalAlpha = 1; break;
    case E.STARCORE: { // estrela de 8 pontas com núcleo
      c.beginPath();
      for (let i = 0; i < 16; i++) {
        const a = (i / 16) * Math.PI * 2 - Math.PI / 2;
        const r = i % 2 === 0 ? 10 : 4.5;
        const x = cx + Math.cos(a) * r, y = cy + Math.sin(a) * r;
        i ? c.lineTo(x, y) : c.moveTo(x, y);
      }
      c.closePath(); c.fill();
      c.fillStyle = '#ffe27a';
      c.beginPath(); c.arc(cx, cy, 3, 0, 7); c.fill();
      break;
    }
    case E.ETHER: // círculo vazado com ondas internas
      c.lineWidth = 2;
      c.beginPath(); c.arc(cx, cy, 9, 0, 7); c.stroke();
      c.lineWidth = 1.5;
      c.beginPath(); c.moveTo(9, 12); c.quadraticCurveTo(12, 9, 14, 12); c.quadraticCurveTo(16, 15, 19, 12); c.stroke();
      c.beginPath(); c.moveTo(9, 17); c.quadraticCurveTo(12, 14, 14, 17); c.quadraticCurveTo(16, 20, 19, 17); c.stroke();
      break;
    case E.MONOLITH: // retângulo vertical com brilho no canto superior
      c.fillRect(10, 5, 8, 18);
      c.strokeStyle = 'rgba(255,255,255,0.8)'; c.lineWidth = 1.4;
      c.beginPath(); c.moveTo(11.5, 8); c.lineTo(11.5, 12); c.stroke();
      break;
  }
  return cv;
}

// Anúncio de conquista em tela cheia: novo elemento descoberto (~5s, animação CSS).
let discoveryTimer = 0;
const discoveryQueue = [];
function showDiscoveryBanner(id) {
  if (el.discovery.classList.contains('show')) {
    // outra descoberta em exibição: enfileira para não engolir o anúncio
    if (!discoveryQueue.includes(id)) discoveryQueue.push(id);
    return;
  }
  const def = ELEMENTS[id];
  el.discovery.style.setProperty('--disc-color', def.color);
  el.discoveryIcon.innerHTML = '';
  el.discoveryIcon.appendChild(iconCanvas(id));
  el.discoveryName.textContent = def.name;
  el.discoveryDesc.textContent = def.desc;
  el.discovery.classList.remove('show');
  void el.discovery.offsetWidth; // força reflow para reiniciar a animação
  el.discovery.classList.add('show');
  clearTimeout(discoveryTimer);
  discoveryTimer = setTimeout(() => {
    el.discovery.classList.remove('show');
    if (discoveryQueue.length) showDiscoveryBanner(discoveryQueue.shift());
  }, 5100);
}

// Banner de era: aparece no centro-alto e some sozinho (~4s, animação CSS).
let eraBannerTimer = 0;
export function showEraBanner(era) {
  const b = el.eraBanner;
  b.textContent = `${era.icon} ${era.name}`;
  b.classList.remove('show');
  void b.offsetWidth; // força reflow para reiniciar a animação
  b.classList.add('show');
  clearTimeout(eraBannerTimer);
  eraBannerTimer = setTimeout(() => b.classList.remove('show'), 4200);
}

// Log de eventos em aba: fechado por padrão, o botão 📜 mostra não-lidos.
let feedOpen = false;
let feedUnread = 0;

export function pushFeed(msg, color) {
  const d = document.createElement('div');
  d.className = 'feeditem';
  d.style.borderLeftColor = color || '#888';
  d.textContent = msg;
  el.feed.prepend(d);
  while (el.feed.children.length > 60) el.feed.lastChild.remove();
  if (!feedOpen) {
    feedUnread = Math.min(99, feedUnread + 1);
    updateFeedTab();
  }
}

function setFeedOpen(open) {
  feedOpen = open;
  el.feed.classList.toggle('hidden', !open);
  el.feedTab.classList.toggle('active', open);
  if (open) feedUnread = 0;
  updateFeedTab();
}

function updateFeedTab() {
  el.feedTab.textContent = feedUnread > 0 ? `📜 Eventos (${feedUnread})` : '📜 Eventos';
}

let selectedBuilding = null;

export function selectCreature(c) {
  game.selected = c;
  if (c) selectedBuilding = null;
  el.inspector.classList.toggle('hidden', !c && !selectedBuilding);
  if (c) refreshInspector(true);
}

// Inspetor de construções: reusa o painel do inspetor de criaturas.
// selectCreature e selectBuilding são mutuamente exclusivos.
export function selectBuilding(b) {
  selectedBuilding = b || null;
  if (b) game.selected = null;
  el.inspector.classList.toggle('hidden', !b && !game.selected);
  if (b) refreshBuildingInspector();
}

function refreshBuildingInspector() {
  const b = selectedBuilding;
  if (!b) return;
  document.getElementById('inspName').textContent = b.label;
  document.getElementById('inspAge').textContent = '';
  const f = document.getElementById('inspFaction');
  if (b.faction) { f.textContent = `⚑ ${b.faction.name}`; f.style.color = b.faction.color; }
  else { f.textContent = 'sem facção'; f.style.color = '#777'; }
  document.getElementById('inspParents').textContent = `Construída por ${b.builder ? b.builder.name : '?'}`;
  document.getElementById('inspStats').textContent = `HP ${Math.ceil(b.hp)}/${b.maxHp}`;
  document.getElementById('inspTraits').innerHTML = '';
  document.getElementById('inspGifts').innerHTML = '';
  const ab = document.getElementById('inspAbsorbed');
  if (b.burning > 0) { ab.textContent = '🔥 em chamas'; ab.style.color = '#ff6a2a'; }
  else { ab.textContent = ''; ab.style.color = ''; }
  // retrato estático: quadrado na cor do elemento
  const ctx = portraitCtx;
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.clearRect(0, 0, 110, 110);
  ctx.fillStyle = '#141821'; ctx.fillRect(0, 0, 110, 110);
  ctx.fillStyle = elemColor(b.element);
  ctx.fillRect(39, 39, 32, 32);
  ctx.strokeStyle = '#fff'; ctx.lineWidth = 1.5;
  ctx.strokeRect(39.5, 39.5, 31, 31);
}

function refreshInspector(force) {
  const c = game.selected;
  if (!c) return;
  if (!c.alive) { selectCreature(null); return; }
  document.getElementById('inspAbsorbed').style.color = '';
  const mins = Math.floor(c.age / 60), secs = Math.floor(c.age % 60);
  document.getElementById('inspName').textContent =
    c.name + (c.archetype ? ' · ' + c.archetype.name : '')
    + (c.giantTier > 0 ? ` · ${ENDGAME.GIANT_TIER_NAMES[c.giantTier - 1]} ${c.sizeMul.toFixed(1)}×` : '')
    + (c.isFirst ? ' ★ (o Primeiro)' : '');
  document.getElementById('inspAge').textContent = `idade ${mins}m${String(secs).padStart(2, '0')}s · ❤ ${Math.ceil(c.hp)}/${Math.ceil(c.stats.maxHp)}`;
  const f = document.getElementById('inspFaction');
  if (c.faction) { f.textContent = `⚑ ${c.faction.name}`; f.style.color = c.faction.color; }
  else { f.textContent = 'sem facção'; f.style.color = '#777'; }
  const pr = document.getElementById('inspParents');
  if (c.parents) pr.textContent = `Filho(a) de ${c.parents[0]}` + (c.parents[1] ? ` e ${c.parents[1]}` : '');
  else pr.textContent = c.isFirst ? 'Origem: O Primeiro' : '';
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
  // dons elementais despertados (abaixo dos traits)
  const gi = document.getElementById('inspGifts');
  gi.innerHTML = '';
  for (const g of c.gifts) {
    const s = document.createElement('span');
    s.className = 'trait';
    s.style.borderColor = elemColor(g);
    s.textContent = '✨ ' + ELEMENT_GIFTS[g].name;
    gi.appendChild(s);
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
  const scale = 42 / Math.max(8, c.bodyPlan.size * (c.sizeMul || 1) + (c.bodyPlan.spikes ? 5 : 0));
  ctx.setTransform(scale, 0, 0, scale, 55 - c.x * scale, 62 - c.y * scale);
  drawCreature(ctx, c, performance.now() / 1000, true);
}

export function updateHUD() {
  el.pop.textContent = `pop ${game.creatures.length}`;
  el.factions.textContent = `facções ${game.factions.filter(f => f.members.length > 1).length}`;
  const era = ERAS[game.era] || ERAS[0];
  el.eraLabel.textContent = `${era.icon} ${era.short}`;
  const m = Math.floor(game.time / 60), s = Math.floor(game.time % 60);
  el.worldTime.textContent = `${m}:${String(s).padStart(2, '0')}`;

  if (el.purgeBadge) {
    if (game.purgeLevel > 0) {
      el.purgeBadge.style.display = '';
      el.purgeBadge.textContent = game.purgeLevel >= 2 ? '🌀 devorando (auge)' : '🌀 devorando';
    } else {
      el.purgeBadge.style.display = 'none';
    }
  }

  // cooldowns (raros e fundidos: qualquer elemento com cooldown > 0)
  for (const def of ELEMENTS) {
    if (!(def.cooldown > 0)) continue;
    const b = paletteBtns.get(def.id);
    const cd = b.querySelector('.cd');
    const rem = game.cooldowns[def.id] || 0;
    cd.style.height = rem > 0 ? `${(rem / def.cooldown) * 100}%` : '0%';
  }

  // legenda da lente de facções: monta a cada ~10 frames e só toca o DOM
  // quando o conteúdo mudou (innerHTML por frame derruba o framerate)
  if (game.lensFactions) {
    el.lensLegend.classList.remove('hidden');
    legendTimer -= 1;
    if (legendTimer <= 0) {
      legendTimer = 10;
      let html = '';
      for (const f of game.factions) {
        if (f.members.length < 1) continue;
        let war = false;
        for (const [, rel] of f.relations) if (rel.state === 'war') { war = true; break; }
        html += `<div><span class="sw" style="background:${f.color}"></span>${f.name} (${f.members.length})${war ? ' ⚔' : ''}</div>`;
      }
      html = html || '<span class="dim">nenhuma facção ainda</span>';
      if (html !== legendHtml) { legendHtml = html; el.lensLegend.innerHTML = html; }
    }
  } else {
    el.lensLegend.classList.add('hidden');
    legendTimer = 0;
  }

  inspectorTimer -= 1;
  if (inspectorTimer <= 0) {
    inspectorTimer = 6;
    if (game.selected) refreshInspector();
    else if (selectedBuilding) {
      // fecha se a construção foi destruída; senão atualiza HP/estado
      if (game.buildings.indexOf(selectedBuilding) === -1) selectBuilding(null);
      else refreshBuildingInspector();
    }
  }
}

