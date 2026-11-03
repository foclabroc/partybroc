// Expressions à trous.   PB_DB_URL=postgresql://… PB_FAST=1 node test/expressions.test.js
import assert from 'node:assert/strict';
import { startServer, client } from './lib.js';

const PORT = 4196;
const srv = await startServer(PORT, { PB_FAST: '1', PB_ROOMS_PER_IP: '100' });
let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const g = (m) => ({ t: 'game_msg', m });

try {
  if (!process.env.PB_DB_URL) {
    console.log('  (sans PB_DB_URL : test Expressions sauté)');
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

    a.send({ t: 'select_game', game: 'expressions' });
    a.send({ t: 'game_option', key: 'rounds', value: 6 });
    await sleep(100);
    a.send({ t: 'start_game' });
    const pg = (await import('pg')).default;
    const db = new pg.Client({ connectionString: process.env.PB_DB_URL });
    await db.connect();

    // Manches 1 à 4 : 1 à 3 « mot qui manque », la 4e « Que veut dire… ? »
    for (let k = 0; k < 4; k++) {
      const r = await tv.room((r) => r.game?.id === 'expressions' && r.game.phase === 'ask' && r.game.index === k, 8000);
      let st = r.room.game;
      assert.equal(st.count, 6);
      assert.equal(st.choices.length, 4);
      assert.equal(new Set(st.choices).size, 4, '4 choix différents');
      assert.equal(st.correct, undefined, 'pas de réponse avant la révélation');
      assert.equal(st.meaning, undefined);
      assert.equal(st.answer, undefined);
      let good;
      if (k < 3) {
        assert.equal(st.kind, 'trou');
        assert.equal(st.text.split('___').length, 2, 'un seul trou');
        const row = (await db.query('select answer from pb.pb_expressions where text = $1', [st.text])).rows[0];
        good = st.choices.indexOf(row.answer);
      } else {
        assert.equal(st.kind, 'sens');
        assert.ok(!st.text.includes('___'), 'expression complète');
        const rows = (await db.query('select text, answer, meaning from pb.pb_expressions')).rows;
        const row = rows.find((x) => x.text.replace('___', x.answer) === st.text);
        good = st.choices.indexOf(row.meaning);
      }
      assert.ok(good >= 0);
      a.send(g({ t: 'exp_pick', r: st.index, choice: good }));
      await sleep(30);
      b.send(g({ t: 'exp_pick', r: st.index, choice: good }));
      c.send(g({ t: 'exp_pick', r: st.index, choice: (good + 1) % 4 }));
      c.send(g({ t: 'exp_pick', r: st.index, choice: good })); // un seul essai
      const rv = await tv.room((r) => r.game?.phase === 'reveal' && r.game.index === k, 6000);
      st = rv.room.game;
      assert.equal(st.correct, good);
      assert.ok(st.full && !st.full.includes('___') && st.meaning);
      const gain = Object.fromEntries(st.ranking.map((x) => [x.pid, x.gain]));
      assert.ok(gain[a.me] >= 200 && gain[b.me] >= 200 && gain[a.me] >= gain[b.me], 'le plus rapide gagne au moins autant');
      assert.equal(gain[c.me] || 0, 0);
      a.send(g({ t: 'game_skip' }));
    }
    await db.end();
    step('Mot qui manque : 3 manches, un seul trou, réponse cachée, points de rapidité, un seul essai');
    step('« Que veut dire… ? » à la 4e manche : expression complète, 4 sens différents, sens donné à la révélation');

    a.send(g({ t: 'game_end' }));
    await tv.room((r) => r.game?.phase === 'podium', 4000);
    step('Podium');
    tv.close(); for (const p of ps) p.close();
  }
  console.log(`Expressions à trous : ${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC :', e);
  process.exitCode = 1;
} finally {
  srv.kill();
}
