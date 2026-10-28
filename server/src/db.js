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

  // ---- salons permanents (sql/06_salons.sql) ----
  // Pour ces fonctions, null = la base ne répond pas (à distinguer de « pas trouvé »)
  async permGet(code) {
    const r = await q('select code, pass_hash from pb.pb_rooms where code = $1', [code]);
    return r ? (r.rows[0] ?? false) : null;
  },

  async permCount() {
    const r = await q('select count(*)::int as n from pb.pb_rooms');
    return r ? r.rows[0].n : null;
  },

  // true = créé, false = ce nom existe déjà, null = base indisponible
  async permCreate(code, passHash) {
    const r = await q(`insert into pb.pb_rooms (code, pass_hash) values ($1, $2)
                       on conflict (code) do nothing returning code`, [code, passHash]);
    return r ? r.rowCount === 1 : null;
  },

  async permUsed(code) {
    await q('update pb.pb_rooms set last_used_at = now() where code = $1', [code]);
  },

  async screenOk(code, keyHash) {
    const r = await q(`update pb.pb_room_screens set last_used_at = now()
                       where code = $1 and key_hash = $2 returning code`, [code, keyHash]);
    return !!r && r.rowCount === 1;
  },

  async screenAdd(code, keyHash) {
    await q('insert into pb.pb_room_screens (code, key_hash) values ($1, $2) on conflict do nothing', [code, keyHash]);
  },

  async members(code) {
    const r = await q(`select member_id, name, emoji, color, score, token_hash from pb.pb_room_members
                       where code = $1 order by last_seen_at desc`, [code]);
    return r ? r.rows : null;
  },

  async memberCreate(code, m) {
    const r = await q(`insert into pb.pb_room_members (code, member_id, name, emoji, color, token_hash)
                       values ($1, $2, $3, $4, $5, $6) on conflict do nothing returning member_id`,
      [code, m.pid, m.name, m.emoji, m.color, m.tokenHash]);
    return !!r && r.rowCount === 1;
  },

  async memberToken(code, mid, tokenHash) {
    await q('update pb.pb_room_members set token_hash = $3, last_seen_at = now() where code = $1 and member_id = $2',
      [code, mid, tokenHash]);
  },

  // Profil et score total du joueur ; playedGame = une partie de plus au compteur
  async memberSaved(code, p, playedGame = false) {
    await q(`update pb.pb_room_members set name = $3, emoji = $4, color = $5, score = $6,
               games = games + $7, last_seen_at = now()
             where code = $1 and member_id = $2`,
      [code, p.pid, p.name, p.emoji, p.color, p.score, playedGame ? 1 : 0]);
  },

  async close() {
    if (pool) await pool.end();
  },
};
