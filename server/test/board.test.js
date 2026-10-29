// Classement sur la TV demandé par l'hôte (sans base).   PB_FAST=1 node test/board.test.js
import assert from 'node:assert/strict';
import { startServer, client } from './lib.js';

const PORT = 4191;
const srv = await startServer(PORT, { PB_FAST: '1', PB_ROOMS_PER_IP: '100' });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };
try {
  const tv = await client(PORT);
  tv.send({ t: 'tv_hello' });
  const { code } = await tv.wait('tv_ok');
  const [a, b] = [await client(PORT), await client(PORT)];
  a.send({ t: 'join', code, name: 'Ana', emoji: '🙂', color: 0, photo: '' }); await a.wait('joined');
  b.send({ t: 'join', code, name: 'Ben', emoji: '🙂', color: 1, photo: '' }); await b.wait('joined');
  b.send({ t: 'tv_board', on: true }); // pas l'hôte : ignoré
  await sleep(200);
  a.send({ t: 'tv_board', on: true });
  await tv.room((r) => r.board === true);
  a.send({ t: 'tv_board', on: false });
  await tv.room((r) => r.board === false);
  step('Seul l’hôte affiche et cache le classement sur la TV');
  a.send({ t: 'tv_board', on: true });
  await tv.room((r) => r.board === true);
  a.send({ t: 'select_game', game: 'calcul' });
  await sleep(100);
  a.send({ t: 'start_game' });
  await tv.room((r) => r.game && r.board === false);
  a.send({ t: 'tv_board', on: true }); // pendant une partie : ignoré
  await sleep(300);
  tv.flush();
  a.send({ t: 'game_msg', m: { t: 'game_end' } });
  const r = await tv.room((r) => r.game?.phase === 'podium');
  assert.equal(r.room.board, false);
  step('Lancer un jeu cache le classement ; pas de classement pendant une partie');
  for (const x of [tv, a, b]) x.close();
  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exitCode = 1;
} finally {
  srv.kill('SIGTERM');
}
