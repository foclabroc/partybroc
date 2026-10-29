// Photos réelles : route /img/<id>, Zoom mystère et Mémoire (sans base).   PB_FAST=1 node test/images.test.js
import assert from 'node:assert/strict';
import { startServer, client } from './lib.js';

const PORT = 4192;
const srv = await startServer(PORT, { PB_FAST: '1', PB_ROOMS_PER_IP: '100' });
let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

try {
  const tv = await client(PORT);
  tv.send({ t: 'tv_hello' });
  const { code } = await tv.wait('tv_ok');
  const a = await client(PORT);
  a.send({ t: 'join', code, name: 'Ana', emoji: '🙂', color: 0, photo: '' });
  await a.wait('joined');
  const live = (cond, ms = 6000) => tv.room((r) => r.game && cond(r.game), ms);

  // ---- Zoom mystère
  a.send({ t: 'select_game', game: 'zoom' });
  await sleep(100);
  a.send({ t: 'start_game' });
  const z = (await live((g) => g.id === 'zoom' && g.phase === 'ask')).room.game;
  assert.match(z.img, /^[0-9a-f]{16}$/, 'identifiant opaque');
  assert.ok(!JSON.stringify(z).includes('.jpg'), 'pas de nom de fichier');
  const r = await fetch(`http://127.0.0.1:${PORT}/img/${z.img}`);
  assert.equal(r.status, 200);
  assert.equal(r.headers.get('content-type'), 'image/jpeg');
  const buf = Buffer.from(await r.arrayBuffer());
  assert.ok(buf[0] === 0xff && buf[1] === 0xd8 && buf.length > 5000, 'un vrai JPEG');
  assert.equal((await fetch(`http://127.0.0.1:${PORT}/img/0123456789abcdef`)).status, 404);
  step('Zoom mystère : photo avec identifiant opaque, servie en JPEG, identifiant inconnu → 404');
  a.send({ t: 'game_msg', m: { t: 'game_end' } });
  await live((g) => g.phase === 'podium');
  a.send({ t: 'game_msg', m: { t: 'game_skip' } });
  await tv.room((r) => r.phase === 'lobby');

  // ---- Mémoire
  a.send({ t: 'select_game', game: 'memoire' });
  await sleep(100);
  a.send({ t: 'start_game' });
  const m = (await live((g) => g.id === 'memoire' && g.phase === 'show')).room.game;
  assert.equal(m.cells.length, 12);
  assert.ok(m.cells.every((c) => /^[0-9a-f]{16}$/.test(c.i)), 'chaque case a sa photo');
  let q = (await live((g) => g.id === 'memoire' && g.phase === 'ask')).room.game;
  if (q.kind === 'emoji') assert.ok(q.imgs.length === q.choices.length && q.imgs.every(Boolean));
  assert.ok(!/\p{Extended_Pictographic}/u.test(q.question) || q.kind !== 'number', 'question au nom, pas à l’emoji');
  step(`Mémoire : photo sur chaque case, question « ${q.question} »`);

  for (const x of [tv, a]) x.close();
  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exitCode = 1;
} finally {
  srv.kill('SIGTERM');
}
