// Emoji rébus (et la Course au tap retirée).   PB_DB_URL=postgresql://… PB_FAST=1 node test/rebus.test.js
import assert from 'node:assert/strict';
import { startServer, client } from './lib.js';

const PORT = 4197;
const srv = await startServer(PORT, { PB_FAST: '1', PB_ROOMS_PER_IP: '100' });
let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const g = (m) => ({ t: 'game_msg', m });

try {
  if (!process.env.PB_DB_URL) {
    console.log('  (sans PB_DB_URL : test Emoji rébus sauté)');
  } else {
    const tv = await client(PORT);
    tv.send({ t: 'tv_hello' });
    const { code } = await tv.wait('tv_ok');
    const ps = [];
    for (const name of ['Ana', 'Bob', 'Cid']) {
      const c = await client(PORT);
      c.send({ t: 'join', code, name, emoji: '🙂', color: 0, photo: '' });
      c.me = (await c.wait('joined')).pid;
      ps.push(c);
    }
    const [a, b, c] = ps;

    // La Course au tap n'existe plus, Emoji rébus est au catalogue
    const lobby = await tv.room((r) => r.players.length === 3);
    const ids = lobby.room.games.map((x) => x.id);
    assert.ok(ids.includes('rebus') && !ids.includes('course'));
    a.send({ t: 'select_game', game: 'course' });
    await sleep(100);
    a.send({ t: 'select_game', game: 'rebus' });
    a.send({ t: 'game_option', key: 'rounds', value: 6 });
    await sleep(100);
    a.send({ t: 'start_game' });
    step('Catalogue : Emoji rébus à la place de la Course au tap');

    let r = await tv.room((r) => r.game?.id === 'rebus' && r.game.phase === 'ask', 8000);
    let st = r.room.game;
    assert.equal(st.count, 6);
    assert.ok(st.emojis && st.category && st.choices.length === 4);
    assert.equal(st.correct, undefined, 'pas de réponse avant la révélation');
    assert.equal(st.hint, undefined);
    step('Question : emojis, catégorie, 4 choix, ni réponse ni explication');

    // On retrouve la bonne réponse en base pour faire jouer les robots
    const pg = (await import('pg')).default;
    const db = new pg.Client({ connectionString: process.env.PB_DB_URL });
    await db.connect();
    const row = (await db.query('select answer from pb.pb_rebus where emojis = $1', [st.emojis])).rows[0];
    await db.end();
    const good = st.choices.indexOf(row.answer);
    assert.ok(good >= 0);
    a.send(g({ t: 'rbs_pick', r: st.index, choice: good }));
    await sleep(30);
    b.send(g({ t: 'rbs_pick', r: st.index, choice: good }));
    c.send(g({ t: 'rbs_pick', r: st.index, choice: (good + 1) % 4 }));
    c.send(g({ t: 'rbs_pick', r: st.index, choice: good })); // un seul essai
    r = await tv.room((r) => r.game?.phase === 'reveal', 6000);
    st = r.room.game;
    assert.equal(st.correct, good);
    assert.ok(typeof st.hint === 'string');
    const gain = Object.fromEntries(st.ranking.map((x) => [x.pid, x.gain]));
    assert.ok(gain[a.me] >= 200 && gain[b.me] >= 200 && gain[a.me] >= gain[b.me], 'le plus rapide gagne au moins autant');
    assert.equal(gain[c.me] || 0, 0);
    step('Révélation : bonne réponse + explication, points de rapidité, un seul essai');

    a.send(g({ t: 'game_end' }));
    await tv.room((r) => r.game?.phase === 'podium', 4000);
    step('Podium');
    tv.close(); for (const p of ps) p.close();
  }
  console.log(`Emoji rébus : ${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC :', e);
  process.exitCode = 1;
} finally {
  srv.kill();
}
