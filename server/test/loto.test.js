// Loto : cartons, vérification des annonces, partie complète (sans base).
//   PB_FAST=1 node test/loto.test.js
import assert from 'node:assert/strict';
import { startServer, client } from './lib.js';
import { makeCarton, fullLines, LotoGame } from '../src/games/loto.js';

const PORT = 4197;
const srv = await startServer(PORT, { PB_FAST: '1', PB_ROOMS_PER_IP: '100' });
let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };

try {
  for (let k = 0; k < 300; k++) {
    const g = makeCarton();
    assert.equal(g.length, 3);
    for (const row of g) assert.equal(row.filter(Boolean).length, 5, '5 numéros par ligne');
    for (let c = 0; c < 9; c++) {
      const col = g.map((r) => r[c]).filter(Boolean);
      assert.ok(col.length >= 1 && col.length <= 3, 'chaque colonne a 1 à 3 numéros');
      const lo = c === 0 ? 1 : c * 10, hi = c === 8 ? 90 : c * 10 + 9;
      assert.ok(col.every((n) => n >= lo && n <= hi), 'colonne ' + c);
      assert.deepEqual(col, [...col].sort((a, b) => a - b), 'rangés de haut en bas');
    }
    assert.equal(new Set(g.flat().filter(Boolean)).size, 15);
  }
  step('300 cartons : 15 numéros, 5 par ligne, colonnes 1-9 … 80-90 rangées');

  {
    const players = new Map([['a', { pid: 'a', connected: true, name: 'A' }], ['b', { pid: 'b', connected: true, name: 'B' }]]);
    const room = { players, hostPid: 'a' };
    const g = new LotoGame(room, { changed() {}, finished() {}, sendTo() {} }, {});
    g.schedule = () => {};
    g.phase = 'draw';
    const card = g.cards.get('a')[0];
    g.claim(players.get('a'));
    assert.equal(g.event.k, 'wrong', 'faux « Quine ! »');
    assert.ok(g.playerState('a').lockedFor > 0);
    g.lock.clear();
    for (const n of card[0]) if (n) { g.drawn.push(n); g.drawnSet.add(n); }
    assert.equal(fullLines(card, g.drawnSet), 1);
    g.claim(players.get('a'));
    assert.equal(g.phase, 'win');
    assert.deepEqual(g.winners[0].pids, ['a']);
    assert.equal(g.scores.get('a'), 300);
    assert.equal(JSON.stringify(g.publicState()).includes(JSON.stringify(card[0])), false, 'le carton n’est pas public');
    step('Faux « Quine ! » bloqué, vraie quine vérifiée avec les boules tirées (300 points)');
  }

  // Partie complète en marquage automatique
  const tv = await client(PORT);
  tv.send({ t: 'tv_hello' });
  const { code } = await tv.wait('tv_ok');
  const cl = [];
  for (const [i, name] of ['Ana', 'Ben'].entries()) {
    const c = await client(PORT);
    c.send({ t: 'join', code, name, emoji: '🙂', color: i, photo: '' });
    await c.wait('joined');
    cl.push(c);
  }
  cl[0].send({ t: 'select_game', game: 'loto' });
  await new Promise((r) => setTimeout(r, 100));
  cl[0].send({ t: 'game_option', key: 'marquage', value: 'Automatique' });
  cl[0].send({ t: 'game_option', key: 'vitesse', value: 'Rapide' });
  await new Promise((r) => setTimeout(r, 100));
  cl[0].send({ t: 'start_game' });
  const fin = await tv.room((r) => r.game?.id === 'loto' && r.game.phase === 'podium', 60000);
  const w = fin.room.game.winners;
  assert.deepEqual(w.map((x) => x.prize), ['quine', 'double', 'plein']);
  const top = fin.room.game.ranking[0].score;
  assert.ok(top >= 1000);
  step(`Partie automatique jusqu’au carton plein en ${fin.room.game.drawn.length} boules`);
  for (const x of [tv, ...cl]) x.close();
  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exitCode = 1;
} finally {
  srv.kill('SIGTERM');
}
