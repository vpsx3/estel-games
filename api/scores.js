import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL || process.env.KV_REST_API_URL,
  token: process.env.UPSTASH_REDIS_REST_TOKEN || process.env.KV_REST_API_TOKEN,
});

const SCORES_KEY = 'pegue_ursinho_global_scores';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();

  // GET — retorna top 10
  if (req.method === 'GET') {
    try {
      const scores = await redis.get(SCORES_KEY) || [];
      return res.status(200).json(scores);
    } catch (e) {
      return res.status(500).json({ error: 'Erro ao buscar scores', detail: String(e), hasUrl: !!(process.env.UPSTASH_REDIS_REST_URL || process.env.KV_REST_API_URL), hasToken: !!(process.env.UPSTASH_REDIS_REST_TOKEN || process.env.KV_REST_API_TOKEN) });
    }
  }

  // POST — salva novo score
  if (req.method === 'POST') {
    try {
      const { nick, seconds, ghosts } = req.body;
      if (!nick || typeof seconds !== 'number') {
        return res.status(400).json({ error: 'Dados inválidos' });
      }
      const scores = await redis.get(SCORES_KEY) || [];
      scores.push({ nick, seconds, ghosts, date: Date.now() });
      scores.sort((a, b) => b.seconds - a.seconds);
      const top10 = scores.slice(0, 10);
      await redis.set(SCORES_KEY, top10);
      const rank = top10.findIndex(s => s.nick === nick && s.seconds === seconds) + 1;
      return res.status(200).json({ rank, scores: top10 });
    } catch (e) {
      return res.status(500).json({ error: 'Erro ao salvar score' });
    }
  }

  return res.status(405).json({ error: 'Método não permitido' });
}
