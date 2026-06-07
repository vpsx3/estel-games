import { Redis } from '@upstash/redis';
import crypto from 'crypto';

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL || process.env.KV_REST_API_URL,
  token: process.env.UPSTASH_REDIS_REST_TOKEN || process.env.KV_REST_API_TOKEN,
});

const SECRET = process.env.SESSION_SECRET || 'troque-este-segredo-em-producao';

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
const MAX_BODY_BYTES = 4096;

// Margem de tolerância entre o tempo do servidor e o score enviado (segundos).
// Cobre latência de rede e o pequeno atraso entre fim de jogo e envio.
const TIME_TOLERANCE = 8;

const GAMES = {
  'pegue-o-ursinho': { maxScore: 3600 },
};

const ALLOWED_ORIGINS = [
  'https://estel.games',
  'https://www.estel.games',
];

function scoresKey(gameId) { return `scores:${gameId}`; }
function usedTokenKey(sid) { return `used:${sid}`; }

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
  if (!/^[a-z0-9-]{1,40}$/.test(id)) return null;
  return GAMES[id] ? id : null;
}

// Verifica assinatura HMAC e retorna o payload, ou null se inválido
function verifyToken(token) {
  if (typeof token !== 'string' || !token.includes('.')) return null;
  const [data, sig] = token.split('.');
  if (!data || !sig) return null;
  const expected = crypto.createHmac('sha256', SECRET).update(data).digest('base64url');
  // comparação em tempo constante (anti timing attack)
  const a = Buffer.from(sig);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;
  try {
    return JSON.parse(Buffer.from(data, 'base64url').toString());
  } catch (e) {
    return null;
  }
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
    if (ratelimit) {
      const ip = getClientIp(req);
      const { success } = await ratelimit.limit(ip);
      if (!success) return res.status(429).json({ error: 'Muitas requisições. Tente novamente em instantes.' });
    }
  } catch (e) { /* não bloqueia */ }

  // GET — top 10
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

  // POST — salva score (exige token válido de sessão)
  if (req.method === 'POST') {
    try {
      const cl = Number(req.headers['content-length'] || 0);
      if (cl > MAX_BODY_BYTES) return res.status(413).json({ error: 'Payload muito grande' });

      const body = req.body || {};
      const gameId = sanitizeGameId(body.game);
      const nick = sanitizeNick(body.nick);
      const seconds = body.seconds;
      const ghosts = body.ghosts;
      const token = body.token;

      if (!gameId) return res.status(400).json({ error: 'Jogo inválido' });
      if (!nick) return res.status(400).json({ error: 'Apelido inválido' });
      if (typeof seconds !== 'number' || !Number.isFinite(seconds) || seconds < 0 || seconds > GAMES[gameId].maxScore) {
        return res.status(400).json({ error: 'Tempo inválido' });
      }
      if (typeof ghosts !== 'number' || !Number.isFinite(ghosts) || ghosts < 1 || ghosts > MAX_GHOSTS) {
        return res.status(400).json({ error: 'Dados inválidos' });
      }

      // --- Validação do token de sessão (anti-cheat) ---
      const payload = verifyToken(token);
      if (!payload || payload.game !== gameId || !payload.sid || !payload.iat) {
        return res.status(403).json({ error: 'Sessão inválida' });
      }

      // tempo real decorrido no servidor
      const elapsedServer = (Date.now() - payload.iat) / 1000;
      // o score não pode exceder o tempo real + tolerância
      if (seconds > elapsedServer + TIME_TOLERANCE) {
        return res.status(403).json({ error: 'Tempo inconsistente' });
      }
      // token não pode ser muito antigo (sessão expira em maxScore + 1min)
      if (elapsedServer > GAMES[gameId].maxScore + 60) {
        return res.status(403).json({ error: 'Sessão expirada' });
      }

      // anti-replay: cada token só conta uma vez
      const usedKey = usedTokenKey(payload.sid);
      const already = await redis.get(usedKey);
      if (already) return res.status(409).json({ error: 'Sessão já utilizada' });
      // marca como usado, expira sozinho depois de 2h
      await redis.set(usedKey, 1, { ex: 7200 });

      // --- Persistência do score ---
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
