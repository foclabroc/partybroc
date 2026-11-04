// « Salons disponibles » : seulement les salons de la même connexion (sans base).
//   PB_FAST=1 node test/nearby.test.js
import assert from 'node:assert/strict';
import { startServer, client } from './lib.js';

const PORT = 4192;
const srv = await startServer(PORT, { PB_FAST: '1', PB_ROOMS_PER_IP: '100' });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };
try {
  const tv = await client(PORT, '10.0.0.1');
  tv.send({ t: 'tv_hello' });
  const { code } = await tv.wait('tv_ok');
  const host = await client(PORT, '10.0.0.1');
  host.send({ t: 'join', code, name: 'Ana', emoji: '🐱', color: 2, photo: '' });
  await host.wait('joined');

  const home = await client(PORT, '10.0.0.1');
  home.send({ t: 'rooms_nearby' });
  const r1 = await home.wait('rooms_nearby');
  assert.equal(r1.rooms.length, 1);
  assert.deepEqual(r1.rooms[0], { code, perm: false, players: 1, max: 15, host: { name: 'Ana', emoji: '🐱', color: 2 }, playing: null });
  step('Même connexion que la TV : le salon est listé (joueurs, hôte)');

  const away = await client(PORT, '10.9.9.9');
  away.send({ t: 'rooms_nearby' });
  const r2 = await away.wait('rooms_nearby');
  assert.equal(r2.rooms.length, 0);
  step('Autre connexion : rien de listé');

  host.send({ t: 'select_game', game: 'calcul' });
  await sleep(100);
  host.send({ t: 'start_game' });
  await tv.room((r) => r.game);
  await sleep(1600);
  home.send({ t: 'rooms_nearby' });
  const r3 = await home.wait('rooms_nearby');
  assert.equal(r3.rooms[0].playing, 'Course de calcul');
  step('Jeu en cours affiché');

  tv.close();
  await sleep(1600);
  home.send({ t: 'rooms_nearby' });
  const r4 = await home.wait('rooms_nearby');
  assert.equal(r4.rooms.length, 0);
  step('Plus d’écran dans le salon : il n’est plus listé');
  for (const x of [host, home, away]) x.close();
  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exitCode = 1;
} finally {
  srv.kill('SIGTERM');
}
