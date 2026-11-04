// Serpents et échelles : déplacements et partie complète (sans base).
//   PB_FAST=1 node test/serpents.test.js
import assert from 'node:assert/strict';
import { startServer, client } from './lib.js';
import { SerpentsGame, LADDERS, SNAKES } from '../src/games/serpents.js';

const PORT = 4196;
const srv = await startServer(PORT, { PB_FAST: '1', PB_ROOMS_PER_IP: '100' });
let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };

function offline(opts = {}) {
  const players = new Map();
  for (let i = 0; i < 3; i++) players.set('p' + i, { pid: 'p' + i, connected: true, name: 'J' + i });
  const g = new SerpentsGame({ players, hostPid: 'p0' }, { changed() {}, finished() {} }, opts);
  g.schedule = () => {};
  return g;
}

try {
  {
    for (const [a, b] of Object.entries(LADDERS)) assert.ok(+a < b, 'une échelle monte');
    for (const [a, b] of Object.entries(SNAKES)) assert.ok(+a > b, 'un serpent descend');
    assert.ok(Object.keys(LADDERS).every((k) => !(k in SNAKES)) && !(100 in SNAKES) && !(100 in LADDERS));
    const g = offline();
    let m = g.move(1, 3);
    assert.deepEqual(m.path, [2, 3, 4]);
    assert.equal(m.kind, 'ladder');
    assert.equal(m.to, 25);
    m = g.move(23, 4);
    assert.equal(m.kind, 'snake');
    assert.equal(m.to, 5);
    m = g.move(98, 4);
    assert.deepEqual(m.path, [99, 100, 99, 98], 'pile sur 100 : on rebondit');
    assert.equal(m.to, 98);
    m = g.move(97, 2);
    assert.equal(m.to, 41, 'case 99 = serpent');
    m = g.move(96, 4);
    assert.equal(m.to, 100);
    const easy = offline({ arrivee: 'Dès 100' });
    m = easy.move(98, 5);
    assert.deepEqual(m.path, [99, 100]);
    assert.equal(m.to, 100, 'Dès 100 : on s’arrête sur la 100');
    step('Échelles, serpents, rebond sur la 100, option « Dès 100 »');
  }
  {
    const g = offline();
    g.phase = 'intro';
    g.nextTurn();
    const first = g.current;
    g.pos.set(first, 10);
    g.roll(g.current);
    const d = g.die;
    g.nextTurn();
    if (d === 6) assert.equal(g.current, first, 'un 6 : même joueur');
    else assert.notEqual(g.current, first, 'sinon joueur suivant');
    assert.equal(g.publicState().event.d, d);
    step(`Tour : le dé (${d}) ${d === 6 ? 'fait rejouer' : 'passe la main'}`);
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
    c.ws.on('message', (dd) => { const m = JSON.parse(dd); if (m.t === 'room' && m.room.game?.id === 'serpents') c.last = m; });
    cl.push(c);
  }
  cl[0].send({ t: 'select_game', game: 'serpents' });
  await new Promise((r) => setTimeout(r, 100));
  cl[0].send({ t: 'start_game' });
  await tv.room((r) => r.game?.id === 'serpents' && r.game.phase === 'turn', 5000);
  const end = Date.now() + 90000;
  let rolls = 0;
  while (Date.now() < end) {
    if (cl[0].last?.room.game?.phase === 'podium') break;
    const me = cl.find((c) => c.last?.you?.myTurn);
    if (me) {
      const seq = me.last.room.game.seq;
      me.send({ t: 'game_msg', m: { t: 'snk_roll' } });
      rolls++;
      const t0 = Date.now();
      while (cl[0].last?.room.game?.seq === seq && Date.now() - t0 < 1000) await new Promise((r) => setTimeout(r, 5));
    } else await new Promise((r) => setTimeout(r, 10));
  }
  const fin = await tv.room((r) => r.game?.phase === 'podium', 5000);
  const g = fin.room.game;
  assert.ok(g.winner);
  assert.equal(g.players.find((p) => p.pid === g.winner).pos, 100);
  assert.equal(g.ranking[0].pid, g.winner);
  assert.equal(g.ranking[0].score, 1000);
  step(`Partie jouée jusqu’à la 100 (${rolls} lancers) : le gagnant a 1000 points`);
  for (const x of [tv, ...cl]) x.close();
  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exitCode = 1;
} finally {
  srv.kill('SIGTERM');
}
