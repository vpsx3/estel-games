import { Redis } from '@upstash/redis';
import { Ratelimit } from '@upstash/ratelimit';

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL || process.env.KV_REST_API_URL,
  token: process.env.UPSTASH_REDIS_REST_TOKEN || process.env.KV_REST_API_TOKEN,
});

const ratelimit = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(10, '10 s'),
  prefix: 'ratelimit:estel',
});

const MAX_SCORES = 10;
const MAX_SECONDS = 3600;
const MAX_GHOSTS = 300;
const MAX_NICK_LEN = 16;

// Jogos válidos e seus limites (whitelist evita criação de chaves arbitrárias)
const GAMES = {
  'pegue-o-ursinho': { maxScore: MAX_SECONDS },
  // novos jogos entram aqui: 'nome-do-jogo': { maxScore: ... },
};

const ALLOWED_ORIGINS = [
  'https://estel.games',
  'https://www.estel.games',
  'https://pegue-o-ursinho-125r.vercel.app',
];

function scoresKey(gameId) {
  return `scores:${gameId}`;
}

function sanitizeNick(raw) {
  if (typeof raw !== 'string') return null;
  let nick = raw.replace(/[\u0000-\u001F\u007F-\u009F]/g, '');
  nick = nick.replace(/[<>"'`&]/g, '');
  nick = nick.trim().slice(0, MAX_NICK_LEN);
  return nick.length > 0 ? nick : null;
}

function sanitizeGameId(raw) {
  if (typeof raw !== 'string') return null;
  const id = raw.trim().toLowerCase();
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

  try {
    const ip = getClientIp(req);
    const { success } = await ratelimit.limit(ip);
    if (!success) {
      return res.status(429).json({ error: 'Muitas requisições. Tente novamente em instantes.' });
    }
  } catch (e) { /* não bloqueia se o limiter falhar */ }

  // GET — top 10 de um jogo: /api/scores?game=pegue-o-ursinho
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

  // POST — salva score: { game, nick, seconds, ghosts }
  if (req.method === 'POST') {
    try {
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
