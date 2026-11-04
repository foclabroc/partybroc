// Yams : calcul des cases, tour automatique et partie complète (sans base).
//   PB_FAST=1 node test/yams.test.js
import assert from 'node:assert/strict';
import { startServer, client } from './lib.js';
import { YamsGame, score, totals, autoPick, CATS } from '../src/games/yams.js';

const PORT = 4197;
const srv = await startServer(PORT, { PB_FAST: '1', PB_ROOMS_PER_IP: '100' });
let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };

try {
  {
    assert.equal(score('full', [3, 3, 3, 1, 1]), 25);
    assert.equal(score('full', [3, 3, 3, 3, 1]), 0);
    assert.equal(score('brelan', [3, 3, 3, 1, 1]), 11);
    assert.equal(score('carre', [3, 3, 3, 1, 1]), 0);
    assert.equal(score('carre', [6, 6, 6, 6, 2]), 26);
    assert.equal(score('petite', [1, 2, 3, 4, 4]), 30);
    assert.equal(score('petite', [6, 3, 5, 4, 1]), 30);
    assert.equal(score('grande', [6, 3, 5, 4, 1]), 0);
    assert.equal(score('grande', [2, 3, 4, 5, 6]), 40);
    assert.equal(score('yams', [4, 4, 4, 4, 4]), 50);
    assert.equal(score('chance', [4, 4, 4, 4, 4]), 20);
    assert.equal(score('3', [3, 3, 1, 3, 6]), 9);
    const t = totals({ 1: 3, 2: 6, 3: 9, 4: 12, 5: 15, 6: 18, yams: 50 });
    assert.deepEqual(t, { up: 63, bonus: 35, low: 50, total: 148 });
    assert.equal(autoPick({}, [3, 3, 3, 1, 1]), 'full');
    step('Cases : Full, Brelan, Carré, suites, Yams, Chance, haut + bonus à 63');
  }
  {
    const players = new Map([['a', { pid: 'a', connected: true, name: 'A' }], ['b', { pid: 'b', connected: false, name: 'B' }]]);
    const g = new YamsGame({ players, hostPid: 'a' }, { changed() {}, finished() {} }, {});
    g.schedule = () => {};
    g.order = ['a', 'b'];
    g.sheets = new Map([['a', {}], ['b', {}]]);
    g.nextTurn();
    assert.equal(g.current, 'a');
    g.onMessage({ pid: 'a' }, { t: 'yms_pick', k: 'chance' });
    assert.equal(g.sheets.get('a').chance, undefined, 'pas de case avant le premier lancer');
    g.onMessage({ pid: 'a' }, { t: 'yms_roll' });
    assert.equal(g.left, 2);
    const keep = g.dice[0];
    g.onMessage({ pid: 'a' }, { t: 'yms_hold', i: 0 });
    g.lastRoll = 0;
    g.onMessage({ pid: 'b' }, { t: 'yms_roll' });
    assert.equal(g.left, 2, 'pas le tour de B');
    g.onMessage({ pid: 'a' }, { t: 'yms_roll' });
    assert.equal(g.dice[0], keep, 'le dé gardé ne bouge pas');
    assert.ok(!g.rolled.includes(0));
    g.onMessage({ pid: 'a' }, { t: 'yms_pick', k: 'chance' });
    assert.equal(g.sheets.get('a').chance, g.dice.reduce((x, y) => x + y, 0));
    assert.equal(g.phase, 'scored');
    g.onMessage({ pid: 'a' }, { t: 'yms_pick', k: '1' });
    assert.equal(g.sheets.get('a')[1], undefined, 'une seule case par tour');
    step('Tour : garder un dé, relancer, une case par tour, pas de case avant de lancer');
  }

  // Partie complète par le serveur, à 2 : chacun remplit ses 13 cases
  const tv = await client(PORT);
  tv.send({ t: 'tv_hello' });
  const { code } = await tv.wait('tv_ok');
  const cl = [];
  for (const [i, name] of ['Ana', 'Ben'].entries()) {
    const c = await client(PORT);
    c.send({ t: 'join', code, name, emoji: '🙂', color: i, photo: '' });
    c.pid = (await c.wait('joined')).pid;
    c.last = null;
    c.ws.on('message', (d) => { const m = JSON.parse(d); if (m.t === 'room' && m.room.game?.id === 'yams') c.last = m; });
    cl.push(c);
  }
  cl[0].send({ t: 'select_game', game: 'yams' });
  await new Promise((r) => setTimeout(r, 100));
  cl[0].send({ t: 'start_game' });
  await tv.room((r) => r.game?.id === 'yams' && r.game.phase === 'turn', 5000);
  const end = Date.now() + 90000;
  let picks = 0;
  while (Date.now() < end) {
    const st = cl[0].last?.room.game;
    if (st?.phase === 'podium') break;
    const me = cl.find((c) => c.last?.you?.myTurn);
    if (me && st.phase === 'turn') {
      const g = me.last.room.game;
      if (g.left === 3) {
        me.send({ t: 'game_msg', m: { t: 'yms_roll' } });
      } else {
        const sheet = g.players.find((p) => p.pid === me.pid).sheet;
        const k = CATS.find((c) => sheet[c] == null);
        const seq = g.seq;
        me.send({ t: 'game_msg', m: { t: 'yms_pick', k } });
        picks++;
        const t0 = Date.now();
        while (cl[0].last?.room.game?.seq === seq && Date.now() - t0 < 1000) await new Promise((r) => setTimeout(r, 5));
      }
      await new Promise((r) => setTimeout(r, 20));
    } else await new Promise((r) => setTimeout(r, 10));
  }
  const fin = await tv.room((r) => r.game?.phase === 'podium', 5000);
  const g = fin.room.game;
  assert.equal(picks, 26);
  for (const p of g.players) {
    assert.equal(Object.keys(p.sheet).length, 13);
    assert.equal(g.ranking.find((r) => r.pid === p.pid).score, p.total);
  }
  step('Partie complète à 2 (26 cases) : points = total de la feuille');
  for (const x of [tv, ...cl]) x.close();
  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exitCode = 1;
} finally {
  srv.kill('SIGTERM');
}
