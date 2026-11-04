// Jeu de l'oie : règles des cases et partie complète (sans base : pas de cases Défi).
//   PB_FAST=1 node test/oie.test.js
import assert from 'node:assert/strict';
import { startServer, client } from './lib.js';
import { OieGame } from '../src/games/oie.js';

const PORT = 4195;
const srv = await startServer(PORT, { PB_FAST: '1', PB_ROOMS_PER_IP: '100' });
let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };

function offline(n = 3, questions = []) {
  const players = new Map();
  for (let i = 0; i < n; i++) players.set('p' + i, { pid: 'p' + i, connected: true, name: 'J' + i });
  const room = { players, hostPid: 'p0', usedQuiz: new Set() };
  const g = new OieGame(room, { changed() {}, finished() {} }, questions);
  g.schedule = () => {};
  return g;
}

try {
  {
    const g = offline();
    const [a, b] = g.order;
    const m = [];
    assert.equal(g.effects(a, 6, 4, m, 'A'), 12, 'pont');
    assert.equal(g.effects(a, 42, 5, m, 'A'), 30, 'labyrinthe');
    assert.equal(g.effects(a, 58, 5, m, 'A'), 0, 'mort');
    assert.equal(g.effects(a, 9, 9, m, 'A'), 63, 'oies enchaînées : 9 → 18 → 27 → … → 63');
    assert.equal(g.advance(60, 7, m, 'A'), 59, 'au-delà de 63 on recule');
    g.pos.set(a, 31);
    assert.equal(g.effects(a, 31, 5, m, 'A'), 31);
    assert.equal(g.stuck.get(a), 'puits');
    g.pos.set(b, 31);
    g.effects(b, 31, 5, m, 'B');
    assert.equal(g.stuck.has(a), false, 'A est délivré du puits');
    assert.equal(g.stuck.get(b), 'puits');
    g.effects(a, 19, 5, m, 'A');
    assert.equal(g.hotel.get(a), 2);
    step('Pont, labyrinthe, mort, oies, rebond sur la 63, puits (délivré par le suivant), hôtel');
  }
  {
    const q = [{ id: 1, text: 'Q ?', answers: ['a', 'b', 'c', 'd'], correct: 2 }];
    const g = offline(2, q);
    const [a] = g.order;
    g.pos.set(a, 10);
    g.turn = 0;
    g.askDefi(a);
    assert.equal(g.phase, 'defi');
    assert.equal(g.publicState().defi.correct, undefined, 'pas de réponse avant la révélation');
    g.onMessage({ pid: a }, { t: 'oie_answer', choice: 2 });
    g.defiReveal();
    assert.equal(g.pos.get(a), 13);
    assert.equal(g.publicState().defi.correct, 2);
    step('Case Défi : la réponse reste cachée, bonne réponse = +3');
  }

  // Partie complète par le serveur, à 3
  const tv = await client(PORT);
  tv.send({ t: 'tv_hello' });
  const { code } = await tv.wait('tv_ok');
  const cl = [];
  for (const [i, name] of ['Ana', 'Ben', 'Cléo'].entries()) {
    const c = await client(PORT);
    c.send({ t: 'join', code, name, emoji: '🙂', color: i, photo: '' });
    c.pid = (await c.wait('joined')).pid;
    c.last = null;
    c.ws.on('message', (d) => { const m = JSON.parse(d); if (m.t === 'room' && m.room.game?.id === 'oie') c.last = m; });
    cl.push(c);
  }
  cl[0].send({ t: 'select_game', game: 'oie' });
  await new Promise((r) => setTimeout(r, 100));
  cl[0].send({ t: 'start_game' });
  await tv.room((r) => r.game?.id === 'oie' && r.game.phase === 'turn', 5000);
  const end = Date.now() + 60000;
  let rolls = 0;
  while (Date.now() < end) {
    if (cl[0].last?.room.game?.phase === 'podium') break;
    const me = cl.find((c) => c.last?.you?.myTurn);
    if (me) {
      const seq = me.last.room.game.seq;
      me.send({ t: 'game_msg', m: { t: 'oie_roll' } });
      rolls++;
      const t0 = Date.now();
      while (cl[0].last?.room.game?.seq === seq && Date.now() - t0 < 1000) await new Promise((r) => setTimeout(r, 5));
    } else await new Promise((r) => setTimeout(r, 10));
  }
  const fin = await tv.room((r) => r.game?.phase === 'podium', 5000);
  const g = fin.room.game;
  assert.ok(g.winner);
  assert.equal(g.players.find((p) => p.pid === g.winner).pos, 63);
  assert.equal(g.ranking[0].pid, g.winner);
  assert.equal(g.ranking[0].score, 1000);
  step(`Partie jouée jusqu’à la 63 (${rolls} lancers) : le gagnant a 1000 points`);
  for (const x of [tv, ...cl]) x.close();
  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exitCode = 1;
} finally {
  srv.kill('SIGTERM');
}
