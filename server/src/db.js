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

  // ---- statistiques des salons permanents (sql/10_stats.sql) ----
  // results : [{pid, score, rank}] ; pid = identifiant du membre
  async statsSaved(code, game, results) {
    for (const r of results) {
      await q(`insert into pb.pb_room_stats (code, member_id, game, played, wins, best, total)
               values ($1, $2, $3, 1, $4, $5::int, $5::bigint)
               on conflict (code, member_id, game) do update set
                 played = pb_room_stats.played + 1,
                 wins = pb_room_stats.wins + excluded.wins,
                 best = greatest(pb_room_stats.best, excluded.best),
                 total = pb_room_stats.total + excluded.total`,
        [code, r.pid, game, r.rank === 1 && r.score > 0 ? 1 : 0, Math.max(0, Math.round(r.score))]);
    }
  },

  // Classement de tous les temps + champion de chaque jeu
  async permStats(code) {
    const m = await q(`select member_id, name, emoji, color, score, games from pb.pb_room_members
                       where code = $1 order by score desc, games desc limit 30`, [code]);
    const g = await q(`select distinct on (s.game) s.game, s.wins, s.best, s.played, m.name, m.emoji, m.color
                       from pb.pb_room_stats s join pb.pb_room_members m using (code, member_id)
                       where s.code = $1 and s.wins > 0
                       order by s.game, s.wins desc, s.best desc`, [code]);
    const tot = await q(`select game, sum(played)::int as played from pb.pb_room_stats where code = $1 group by game`, [code]);
    if (!m || !g || !tot) return null;
    const played = Object.fromEntries(tot.rows.map((r) => [r.game, r.played]));
    return {
      members: m.rows.map((r) => ({ id: r.member_id, name: r.name, emoji: r.emoji, color: r.color, score: Number(r.score), games: r.games })),
      champions: g.rows.map((r) => ({ game: r.game, wins: r.wins, best: Number(r.best), name: r.name, emoji: r.emoji, color: r.color, played: played[r.game] || 0 })),
    };
  },

  async close() {
    if (pool) await pool.end();
  },
};
