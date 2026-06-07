import crypto from 'crypto';

const SECRET = process.env.SESSION_SECRET || 'troque-este-segredo-em-producao';

const GAMES = {
  'pegue-o-ursinho': true,
};

const ALLOWED_ORIGINS = [
  'https://estel.games',
  'https://www.estel.games',
];

function setCors(req, res) {
  const origin = req.headers.origin;
  if (origin && ALLOWED_ORIGINS.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
  }
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Vary', 'Origin');
}

function sign(payload) {
  const data = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const sig = crypto.createHmac('sha256', SECRET).update(data).digest('base64url');
  return `${data}.${sig}`;
}

export default async function handler(req, res) {
  setCors(req, res);
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método não permitido' });

  try {
    const body = req.body || {};
    const game = typeof body.game === 'string' ? body.game.trim().toLowerCase() : '';
    if (!GAMES[game]) return res.status(400).json({ error: 'Jogo inválido' });

    const payload = {
      sid: crypto.randomUUID(),   // id único da sessão (anti-replay)
      game,
      iat: Date.now(),            // timestamp do servidor (início da partida)
    };

    return res.status(200).json({ token: sign(payload) });
  } catch (e) {
    return res.status(500).json({ error: 'Erro ao iniciar sessão' });
  }
}
