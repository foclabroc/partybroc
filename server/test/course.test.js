// Course au tap (sans base).   PB_FAST=1 node test/course.test.js
import assert from 'node:assert/strict';
import { startServer, client } from './lib.js';

const PORT = 4193;
const srv = await startServer(PORT, { PB_FAST: '1', PB_ROOMS_PER_IP: '100' });
let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const g = (m) => ({ t: 'game_msg', m });

try {
  const tv = await client(PORT);
  tv.send({ t: 'tv_hello' });
  const { code } = await tv.wait('tv_ok');
  const ps = [];
  for (const name of ['Ana', 'Ben', 'Cléo']) {
    const c = await client(PORT);
    c.send({ t: 'join', code, name, emoji: '🙂', color: 0, photo: '' });
    c.me = (await c.wait('joined')).pid;
    ps.push(c);
  }
  const [a, b, c] = ps;
  const live = (cond, ms = 6000) => tv.room((r) => r.game && cond(r.game, r), ms);

  a.send({ t: 'select_game', game: 'course' });
  a.send({ t: 'game_option', key: 'races', value: 3 });
  await sleep(100);
  a.send({ t: 'start_game' });

  // ---- 1. Sprint
  let s = (await live((g) => g.id === 'course' && g.phase === 'ready' && g.index === 0)).room.game;
  assert.equal(s.kind, 'sprint'); assert.equal(s.count, 3); assert.equal(s.hurdles.length, 0);
  const L = s.length;
  a.send(g({ t: 'crs', k: 0, n: 10 })); // avant le départ : ignoré
  await live((g) => g.phase === 'go' && g.index === 0);
  b.send(g({ t: 'crs', k: 0, n: 9999 })); // triche : plafonné
  await sleep(300);
  s = (await live((g) => g.phase === 'go' && g.pos[b.me] !== undefined)).room.game;
  assert.ok(s.pos[b.me] < L, 'pas plafonnés');
  assert.equal(s.pos[a.me], undefined, 'rien compté avant le départ');
  step('Sprint : pas comptés seulement après le départ, vitesse plafonnée');

  // On attend que la vitesse max permette d’arriver (60 pas à 24/s ≈ 2,5 s ; course de 5 s ici)
  await sleep(1900);
  a.send(g({ t: 'crs', k: 0, n: L, ms: 9000 }));
  c.send(g({ t: 'crs', k: 0, n: L, ms: 5 })); // temps impossible : ramené au minimum
  b.send(g({ t: 'crs', k: 0, n: 20 }));
  s = (await live((g) => g.phase === 'result' && g.index === 0, 5000)).room.game;
  assert.deepEqual(s.order.map((o) => o.pid), [c.me, a.me, b.me]);
  assert.ok(s.order[0].ms >= Math.ceil((L / 24) * 1000), 'temps minimum');
  assert.ok(s.order[1].ms < 3200, 'temps borné par ce que le serveur a vu');
  assert.deepEqual(s.order.map((o) => o.pts), [500, 400, 100]);
  step('Sprint : arrivées classées au temps (borné), non-arrivé classé à la distance, 500/400/100');

  // ---- 2. Haies
  a.send(g({ t: 'game_skip' }));
  s = (await live((g) => g.phase === 'ready' && g.index === 1)).room.game;
  assert.equal(s.kind, 'haies'); assert.equal(s.hurdles.length, 4);
  assert.ok(s.hurdles.every((h, i) => h > 0 && h < s.length && (i === 0 || h > s.hurdles[i - 1])));
  await live((g) => g.phase === 'go' && g.index === 1);
  a.send(g({ t: 'crs', k: 1, n: 5, s: 99 }));
  s = (await live((g) => g.phase === 'go' && g.index === 1 && g.stumbles[a.me] !== undefined)).room.game;
  assert.equal(s.stumbles[a.me], 4, 'chutes bornées au nombre de haies');
  step('Haies : 4 haies dans l’ordre, chutes comptées et bornées');

  // ---- 3. Turbo : arrêt de la course par l'hôte, puis podium
  a.send(g({ t: 'game_skip' })); // fin de la course 2
  await live((g) => g.phase === 'result' && g.index === 1);
  a.send(g({ t: 'game_skip' }));
  s = (await live((g) => g.phase === 'ready' && g.index === 2)).room.game;
  assert.equal(s.kind, 'turbo'); assert.equal(s.turbos.length, 2);
  assert.ok(s.turbos.every((t) => !s.hurdles.includes(t)), 'turbo jamais sur une haie');
  a.send(g({ t: 'game_end' }));
  s = (await live((g) => g.phase === 'podium')).room.game;
  assert.ok(s.ranking.find((r) => r.pid === c.me).score >= 500);
  step('Turbo : 2 bonus entre les haies ; arrêt par l’hôte → podium avec les points cumulés');

  for (const x of [tv, ...ps]) x.close();
  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exitCode = 1;
} finally {
  srv.kill('SIGTERM');
}
