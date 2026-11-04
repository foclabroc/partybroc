// Broc-Pioche : une partie complète à 3, dénonciation, mains jamais publiques (sans base).
//   PB_FAST=1 node test/pioche.test.js
import assert from 'node:assert/strict';
import { startServer, client } from './lib.js';
import { PiocheGame } from '../src/games/pioche.js';

const PORT = 4193;
const srv = await startServer(PORT, { PB_FAST: '1', PB_ROOMS_PER_IP: '100' });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };

// Règles sur une partie hors serveur (pas de minuteur qui tourne pendant le test)
function offline(n = 3) {
  const players = new Map();
  for (let i = 0; i < n; i++) players.set('p' + i, { pid: 'p' + i, connected: true, name: 'J' + i });
  const room = { players, hostPid: 'p0' };
  const g = new PiocheGame(room, { changed() {}, finished() {} }, {});
  g.phase = 'play';
  g.schedule = () => {};
  return g;
}

try {
  // ---- règles
  {
    const g = offline();
    const [a, b, c] = g.order;
    g.turn = 0; g.color = 'r'; g.discard.push({ id: 900, c: 'r', v: '5' });
    g.hands.set(a, [{ id: 901, c: 'r', v: 'p2' }, { id: 902, c: 'b', v: '1' }]);
    g.hands.set(b, [{ id: 903, c: 'v', v: 'p2' }, { id: 904, c: 'j', v: '3' }, { id: 905, c: 'j', v: '4' }]);
    g.hands.set(c, [{ id: 906, c: 'b', v: '2' }, { id: 907, c: 'b', v: '3' }]);
    assert.equal(g.playable({ c: 'b', v: '1' }), false);
    g.onMessage({ pid: a }, { t: 'pch_play', card: 901 });
    assert.equal(g.current, b);
    assert.equal(g.pending, 2);
    assert.equal(g.exposed, a, 'a n’a plus qu’une carte sans l’avoir annoncé');
    assert.equal(g.playable({ c: 'j', v: '3' }), false, 'avec un +2 à payer, seul un +2 ou un +4 se joue');
    g.onMessage({ pid: c }, { t: 'pch_catch', pid: a });
    assert.equal(g.hands.get(a).length, 3, 'dénoncé : +2');
    g.onMessage({ pid: b }, { t: 'pch_play', card: 903 }); // cumul
    assert.equal(g.pending, 4);
    assert.equal(g.current, c);
    g.onMessage({ pid: c }, { t: 'pch_draw' });
    assert.equal(g.hands.get(c).length, 6);
    assert.equal(g.pending, 0);
    assert.equal(g.current, a);
    step('+2 cumulé, pioche du total, dénonciation de la dernière carte (+2)');
  }
  {
    const g = offline();
    const [a, b, c] = g.order;
    g.turn = 0; g.color = 'r'; g.discard.push({ id: 900, c: 'r', v: '5' });
    g.hands.set(a, [{ id: 901, c: 'r', v: 'skip' }, { id: 902, c: 'w', v: 'joker' }, { id: 910, c: 'v', v: '9' }]);
    g.onMessage({ pid: a }, { t: 'pch_play', card: 901 });
    assert.equal(g.current, c, '« passe » saute b');
    g.turn = 0;
    g.onMessage({ pid: a }, { t: 'pch_play', card: 902 }); // sans couleur : refusé
    assert.equal(g.hands.get(a).length, 2);
    g.onMessage({ pid: a }, { t: 'pch_play', card: 902, color: 'v', last: true });
    assert.equal(g.color, 'v');
    assert.equal(g.exposed, null, 'annoncé en jouant l’avant-dernière');
    assert.ok(g.said.has(a));
    g.turn = 0;
    g.onMessage({ pid: a }, { t: 'pch_play', card: 910 });
    assert.deepEqual(g.finished, [a]);
    assert.equal(g.order.length, 2);
    assert.equal(g.current, b, 'après la dernière carte de a, c’est à b');
    step('Passe, choix de couleur obligatoire, annonce, fin de main et tour suivant');
  }

  // ---- partie complète par le serveur
  const tv = await client(PORT);
  tv.send({ t: 'tv_hello' });
  const { code } = await tv.wait('tv_ok');
  const names = ['Ana', 'Ben', 'Cléo'];
  const cl = [];
  for (const [i, name] of names.entries()) {
    const c = await client(PORT);
    c.send({ t: 'join', code, name, emoji: '🙂', color: i, photo: '' });
    const j = await c.wait('joined');
    c.pid = j.pid;
    c.last = null;
    c.ws.on('message', (d) => { const m = JSON.parse(d); if (m.t === 'room' && m.room.game?.id === 'pioche') c.last = m; });
    cl.push(c);
  }
  let leaks = 0;
  tv.ws.on('message', (d) => { if (/"hand"/.test(d.toString())) leaks++; });
  cl[0].send({ t: 'select_game', game: 'pioche' });
  await sleep(100);
  cl[0].send({ t: 'game_option', key: 'cards', value: 5 });
  await sleep(100);
  cl[0].send({ t: 'start_game' });
  const r0 = await tv.room((r) => r.game?.id === 'pioche' && r.game.phase === 'play', 5000);
  assert.equal(r0.room.game.order.length, 3);
  assert.ok(r0.room.game.order.every((o) => o.n === 5));
  assert.equal(JSON.stringify(r0.room).includes('"hand"'), false);
  step('La partie démarre : 5 cartes chacun, la TV ne voit que le nombre de cartes');

  // Chaque joueur joue sa première carte possible, sinon pioche, puis passe
  let moves = 0;
  const end = Date.now() + 20000;
  while (Date.now() < end) {
    const st = cl.map((c) => c.last).find((m) => m?.you?.myTurn);
    const g = cl[0].last?.room.game;
    if (g?.phase === 'podium') break;
    if (!st) { await sleep(20); continue; }
    const me = cl.find((c) => c.last === st);
    const seq = g?.seq;
    const card = st.you.hand.find((c) => st.you.playable.includes(c.id));
    if (card) {
      const last = st.you.hand.length === 2;
      me.send({ t: 'game_msg', m: { t: 'pch_play', card: card.id, color: card.c === 'w' ? 'b' : undefined, last } });
    } else if (st.you.drawn != null) me.send({ t: 'game_msg', m: { t: 'pch_pass' } });
    else me.send({ t: 'game_msg', m: { t: 'pch_draw' } });
    moves++;
    const t0 = Date.now();
    while (cl[0].last?.room.game?.seq === seq && Date.now() - t0 < 1500) await sleep(10);
  }
  const fin = await tv.room((r) => r.game?.phase === 'podium', 5000);
  const ranking = fin.room.game.ranking;
  assert.equal(ranking.length, 3);
  assert.deepEqual(ranking.map((r) => r.score), [1000, 850, 700]);
  assert.equal(fin.room.game.finished.length, 3);
  assert.equal(leaks, 0, 'aucune main envoyée à la TV');
  step(`Partie jouée jusqu’au bout (${moves} coups) : podium 1000 / 850 / 700, aucune main sur la TV`);

  for (const x of [tv, ...cl]) x.close();
  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exitCode = 1;
} finally {
  srv.kill('SIGTERM');
}
