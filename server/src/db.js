// Historique en base (PostgreSQL, base « party »).
// Tout est « au mieux » : si la base ne répond pas, le jeu continue.
import pg from 'pg';
import { config } from './config.js';

let pool = null;
if (config.dbUrl) {
  pool = new pg.Pool({ connectionString: config.dbUrl, max: 4 });
  pool.on('error', (e) => console.warn('[db] erreur', e.message));
}

async function q(sql, params) {
  if (!pool) return null;
  try {
    return await pool.query(sql, params);
  } catch (e) {
    console.warn('[db]', e.message);
    return null;
  }
}

export const db = {
  enabled: () => pool !== null,

  async check() {
    const r = await q('select 1 as ok');
    return r !== null;
  },

  async partyOpened(code) {
    const r = await q('insert into pb.pb_parties (code) values ($1) returning id', [code]);
    return r?.rows[0]?.id ?? null;
  },

  async partyClosed(partyId, maxPlayers) {
    if (!partyId) return;
    await q('update pb.pb_parties set closed_at = now(), max_players = greatest(max_players, $2) where id = $1',
      [partyId, maxPlayers]);
  },

  async playerSeen(partyId, playerId, name, score) {
    if (!partyId) return;
    await q(`insert into pb.pb_party_players (party_id, player_id, name, score) values ($1, $2, $3, $4)
             on conflict (party_id, player_id) do update set name = excluded.name, score = excluded.score`,
      [partyId, playerId, name, score]);
  },

  // Questions du quiz au hasard, sans celles déjà posées ce soir.
  // Renvoie null si la base ne répond pas.
  async quizQuestions(n, excludeIds) {
    const r = await q(`select id, category, difficulty, question, good, bad from pb.pb_quiz_questions
                       where active and not (id = any($2::int[]))
                       order by random() limit $1`, [n, excludeIds]);
    return r ? r.rows : null;
  },

  // Contenu d'un jeu tiré au hasard (table pb.<table>, colonne id), sans ce qui a déjà servi ce soir
  async randomContent(table, cols, n, excludeIds) {
    if (!/^pb_[a-z_]+$/.test(table) || !/^[a-z_, ]+$/.test(cols)) throw new Error('table invalide');
    const r = await q(`select id, ${cols} from pb.${table}
                       where active and not (id = any($2::int[]))
                       order by random() limit $1`, [n, excludeIds]);
    return r ? r.rows : null;
  },

  async gameSaved(partyId, game, startedAt, results) {
    if (!partyId) return;
    await q(`insert into pb.pb_games (party_id, game, started_at, ended_at, results)
             values ($1, $2, $3, now(), $4)`, [partyId, game, new Date(startedAt), JSON.stringify(results)]);
  },

  async close() {
    if (pool) await pool.end();
  },
};
