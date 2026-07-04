#!/usr/bin/env node
// Inlina os módulos de /src dentro do index.html (entre os marcadores BUNDLE),
// para que o jogo rode abrindo o index.html direto do disco (file://) —
// browsers bloqueiam import de ES modules via file:// por CORS.
//
// Uso: node build.mjs   (rodar após editar qualquer arquivo de /src)
// O código-fonte canônico continua sendo /src (ES modules); para desenvolver
// com os módulos direto, sirva a pasta (ex.: python3 -m http.server) e abra dev.html.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// ordem de dependência (sem imports circulares)
const ORDER = ['rng', 'names', 'elements', 'world', 'evolution', 'building', 'society', 'creature', 'render', 'ui', 'main'];

const parts = [];
for (const name of ORDER) {
  let src = fs.readFileSync(path.join(__dirname, 'src', name + '.js'), 'utf8');
  const exported = [];
  // import { a, b } from './x.js'  ->  const { a, b } = __m.x
  src = src.replace(/^import\s*\{([^}]*)\}\s*from\s*'\.\/(\w+)\.js';?\s*$/gm,
    (_, names, mod) => `const {${names}} = __m.${mod};`);
  // export function/class/const/let X  ->  registra e remove o export
  src = src.replace(/^export\s+(function|class|const|let)\s+([A-Za-z_$][\w$]*)/gm,
    (_, kind, id) => { exported.push(id); return `${kind} ${id}`; });
  const ret = exported.length ? `\nreturn { ${exported.join(', ')} };` : '';
  parts.push(`// ==== src/${name}.js ====\n__m.${name} = (() => {\n${src}${ret}\n})();`);
}

const bundle = `(() => {\n'use strict';\nconst __m = {};\n${parts.join('\n\n')}\n})();`;

const htmlPath = path.join(__dirname, 'index.html');
let html = fs.readFileSync(htmlPath, 'utf8');
const START = '<!-- BUNDLE:START (gerado por build.mjs — não editar à mão) -->';
const OLD_START = '<!-- BUNDLE:START (gerado por build.js — não editar à mão) -->';
const END = '<!-- BUNDLE:END -->';
const block = `${START}\n<script>\n${bundle}\n</script>\n${END}`;
const esc = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const re = new RegExp(`(?:${esc(START)}|${esc(OLD_START)})[\\s\\S]*?${esc(END)}`);
if (re.test(html)) html = html.replace(re, block);
else html = html.replace(/<script type="module" src="src\/main\.js"><\/script>/, block);
fs.writeFileSync(htmlPath, html);

// dev.html: mesma página usando os ES modules direto (requer servir a pasta)
const dev = html.replace(re, '<script type="module" src="src/main.js"></script>');
fs.writeFileSync(path.join(__dirname, 'dev.html'), dev);
console.log('index.html (bundle inline) e dev.html (ES modules) atualizados —', ORDER.length, 'módulos.');
