import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL || process.env.KV_REST_API_URL,
  token: process.env.UPSTASH_REDIS_REST_TOKEN || process.env.KV_REST_API_TOKEN,
});

// Rate limiter opcional — não derruba o serviço se a dependência faltar.
let ratelimit = null;
try {
  const { Ratelimit } = await import('@upstash/ratelimit');
  ratelimit = new Ratelimit({
    redis,
    limiter: Ratelimit.slidingWindow(10, '10 s'),
    prefix: 'rl:estel',
  });
} catch (e) {
  ratelimit = null;
}

const MAX_SCORES = 10;
const MAX_GHOSTS = 300;
const MAX_NICK_LEN = 16;
const MAX_BODY_BYTES = 2048; // payload guard

// Whitelist de jogos. Cada novo jogo do portal entra aqui.
const GAMES = {
  'pegue-o-ursinho': { maxScore: 3600 }, // teto: 1h de sobrevivência
};

const ALLOWED_ORIGINS = [
  'https://estel.games',
  'https://www.estel.games',
];

function scoresKey(gameId) {
  return `scores:${gameId}`;
}

function sanitizeNick(raw) {
  if (typeof raw !== 'string') return null;
  let nick = raw.replace(/[\u0000-\u001F\u007F-\u009F]/g, ''); // controle
  nick = nick.replace(/[<>"'`&]/g, '');                        // HTML/script
  nick = nick.trim().slice(0, MAX_NICK_LEN);
  return nick.length > 0 ? nick : null;
}

// gameId só pode conter letras minúsculas, números e hífen; e tem que existir na whitelist
function sanitizeGameId(raw) {
  if (typeof raw !== 'string') return null;
  const id = raw.trim().toLowerCase();
  if (!/^[a-z0-9-]{1,40}$/.test(id)) return null;
  return GAMES[id] ? id : null;
}

function setCors(req, res) {
  const origin = req.headers.origin;
  if (origin && ALLOWED_ORIGINS.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
  }
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Vary', 'Origin');
}

function getClientIp(req) {
  const fwd = req.headers['x-forwarded-for'];
  if (typeof fwd === 'string') return fwd.split(',')[0].trim();
  return req.headers['x-real-ip'] || 'unknown';
}

export default async function handler(req, res) {
  setCors(req, res);
  if (req.method === 'OPTIONS') return res.status(200).end();

  // Rate limiting (se disponível)
  try {
    if (ratelimit) {
      const ip = getClientIp(req);
      const { success } = await ratelimit.limit(ip);
      if (!success) {
        return res.status(429).json({ error: 'Muitas requisições. Tente novamente em instantes.' });
      }
    }
  } catch (e) { /* não bloqueia se o limiter falhar */ }

  // GET — top 10 de um jogo
  if (req.method === 'GET') {
    try {
      const gameId = sanitizeGameId(req.query.game);
      if (!gameId) return res.status(400).json({ error: 'Jogo inválido' });
      const scores = (await redis.get(scoresKey(gameId))) || [];
      return res.status(200).json(scores);
    } catch (e) {
      return res.status(500).json({ error: 'Erro ao buscar scores' });
    }
  }

  // POST — salva score
  if (req.method === 'POST') {
    try {
      // payload guard
      const cl = Number(req.headers['content-length'] || 0);
      if (cl > MAX_BODY_BYTES) {
        return res.status(413).json({ error: 'Payload muito grande' });
      }

      const body = req.body || {};
      const gameId = sanitizeGameId(body.game);
      const nick = sanitizeNick(body.nick);
      const seconds = body.seconds;
      const ghosts = body.ghosts;

      if (!gameId) return res.status(400).json({ error: 'Jogo inválido' });
      if (!nick) return res.status(400).json({ error: 'Apelido inválido' });
      if (typeof seconds !== 'number' || !Number.isFinite(seconds) || seconds < 0 || seconds > GAMES[gameId].maxScore) {
        return res.status(400).json({ error: 'Tempo inválido' });
      }
      if (typeof ghosts !== 'number' || !Number.isFinite(ghosts) || ghosts < 1 || ghosts > MAX_GHOSTS) {
        return res.status(400).json({ error: 'Dados inválidos' });
      }

      const secondsInt = Math.floor(seconds);
      const ghostsInt = Math.floor(ghosts);
      const key = scoresKey(gameId);
      const scores = (await redis.get(key)) || [];

      const existing = scores.find(s => s.nick === nick);
      if (existing) {
        if (secondsInt > existing.seconds) {
          existing.seconds = secondsInt;
          existing.ghosts = ghostsInt;
          existing.date = Date.now();
        }
      } else {
        scores.push({ nick, seconds: secondsInt, ghosts: ghostsInt, date: Date.now() });
      }

      scores.sort((a, b) => b.seconds - a.seconds);
      const top = scores.slice(0, MAX_SCORES);
      await redis.set(key, top);

      const rank = top.findIndex(s => s.nick === nick) + 1;
      return res.status(200).json({ rank: rank || null, scores: top });
    } catch (e) {
      return res.status(500).json({ error: 'Erro ao salvar score' });
    }
  }

  return res.status(405).json({ error: 'Método não permitido' });
}
