// Loto : série de cartons, choix des cartons, vérification des annonces, partie complète (sans base).
//   PB_FAST=1 node test/loto.test.js
import assert from 'node:assert/strict';
import { startServer, client } from './lib.js';
import { CARTONS, SERIES, cartonOf, fullLines, LotoGame } from '../src/games/loto.js';

const PORT = 4197;
const srv = await startServer(PORT, { PB_FAST: '1', PB_ROOMS_PER_IP: '100' });
let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };

function offline(names = ['a', 'b'], opts = {}) {
  const players = new Map(names.map((pid) => [pid, { pid, connected: true, name: pid.toUpperCase() }]));
  const room = { players, hostPid: names[0] };
  const g = new LotoGame(room, { changed() {}, finished() {}, sendTo() {} }, opts);
  g.schedule = () => {};
  return g;
}

try {
  assert.equal(CARTONS.length, SERIES);
  assert.equal(new Set(CARTONS.map((c) => JSON.stringify(c))).size, SERIES, 'tous différents');
  for (const g of CARTONS) {
    for (const row of g) assert.equal(row.filter(Boolean).length, 5, '5 numéros par ligne');
    for (let c = 0; c < 9; c++) {
      const col = g.map((r) => r[c]).filter(Boolean);
      assert.ok(col.length >= 1 && col.length <= 3, 'chaque colonne a 1 à 3 numéros');
      const lo = c === 0 ? 1 : c * 10, hi = c === 8 ? 90 : c * 10 + 9;
      assert.ok(col.every((n) => n >= lo && n <= hi), 'colonne ' + c);
      assert.deepEqual(col, [...col].sort((a, b) => a - b), 'rangés de haut en bas');
    }
  }
  step('Série de 300 cartons tous différents : 15 numéros, 5 par ligne, colonnes 1-9 … 80-90');

  {
    const names = Array.from({ length: 15 }, (_, i) => 'p' + i);
    const g = offline(names, { cartons: 2 });
    g.phase = 'choose';
    const all = names.flatMap((pid) => g.pools.get(pid));
    assert.equal(all.length, 300);
    assert.equal(new Set(all).size, 300, '15 joueurs × 20 cartons, aucun en commun');
    const [x, y, z] = g.pools.get('p0');
    const a = g.room.players.get('p0');
    g.pick(a, g.pools.get('p1')[0]);
    assert.deepEqual(g.mine.get('p0'), [], 'pas le carton d’un autre');
    g.pick(a, x); g.pick(a, y); g.pick(a, z);
    assert.deepEqual(g.mine.get('p0'), [y, z], '3e coché : le plus ancien est décoché');
    g.pick(a, z);
    assert.deepEqual(g.mine.get('p0'), [y], 'décocher');
    g.setReady(a);
    assert.equal(g.ready.has('p0'), false, '« Commencer » seulement avec 2 cartons');
    g.pick(a, x);
    g.setReady(a);
    assert.equal(g.ready.has('p0'), true);
    g.chosen();
    for (const pid of names) assert.equal(g.mine.get(pid).length, 2);
    step('Liste de 20 cartons par joueur sans doublon, cocher / décocher, « Commencer » à 2 cartons, complété à la fin');
  }

  {
    const g = offline();
    g.mine.set('a', [7]);
    g.mine.set('b', [8]);
    g.phase = 'draw';
    const card = cartonOf(7);
    g.claim(g.room.players.get('a'));
    assert.equal(g.event.k, 'wrong', 'fausse annonce');
    assert.ok(g.playerState('a').lockedFor > 0);
    g.lock.clear();
    for (const n of card[0]) if (n) { g.drawn.push(n); g.drawnSet.add(n); }
    assert.equal(fullLines(card, g.drawnSet), 1);
    g.claim(g.room.players.get('a'));
    assert.equal(g.phase, 'win');
    assert.equal(g.winners[0].prize, 'ligne');
    assert.equal(g.scores.get('a'), 300);
    step('Fausse annonce bloquée, « Une ligne » vérifiée avec les boules tirées (300 points)');
  }

  // Partie complète en marquage automatique (cartons donnés au hasard à la fin du choix)
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
  const ch = await tv.room((r) => r.game?.id === 'loto' && r.game.phase === 'choose', 5000);
  assert.equal(JSON.stringify(ch.room).includes('"pool"'), false, 'les listes de cartons ne vont pas à la TV');
  const fin = await tv.room((r) => r.game?.id === 'loto' && r.game.phase === 'podium', 60000);
  const w = fin.room.game.winners;
  assert.deepEqual(w.map((x) => x.prize), ['ligne', 'deux', 'plein']);
  assert.ok(fin.room.game.ranking[0].score >= 1000);
  step(`Partie automatique jusqu’au carton plein en ${fin.room.game.drawn.length} boules`);
  for (const x of [tv, ...cl]) x.close();
  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exitCode = 1;
} finally {
  srv.kill('SIGTERM');
}
