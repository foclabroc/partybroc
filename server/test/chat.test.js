// Messages et réactions en direct : relayés à la TV et aux autres, nettoyés, limités.
import assert from 'node:assert/strict';
import { startServer, client } from './lib.js';

const PORT = 4195;
const srv = await startServer(PORT, { PB_FAST: '1' });
let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };

try {
  const tv = await client(PORT);
  tv.send({ t: 'tv_hello' });
  const { code } = await tv.wait('tv_ok');
  assert.deepEqual((await tv.wait('chat_log')).items, []);
  const a = await client(PORT);
  a.send({ t: 'join', code, name: 'Alice', emoji: '🦊', color: 1, photo: '' });
  const ja = await a.wait('joined');
  await a.wait('chat_log');
  const b = await client(PORT);
  b.send({ t: 'join', code, name: 'Bob', emoji: '🐸', color: 2, photo: '' });
  await b.wait('joined');

  a.send({ t: 'chat', text: '  Salut​   la   famille 👨‍👩‍👧 ' + 'x'.repeat(100) });
  const [mt, mb] = await Promise.all([tv.wait('chat'), b.wait('chat')]);
  assert.equal(mt.pid, ja.pid);
  assert.equal(mt.name, 'Alice');
  assert.ok(mt.text.startsWith('Salut la famille 👨‍👩‍👧 x'));
  assert.equal([...mt.text].length, 80);
  assert.equal(mb.id, mt.id);
  step('Message : relayé à la TV et aux joueurs, espaces et caractères invisibles enlevés, emoji famille gardé, 80 caractères max');

  a.send({ t: 'react', e: '🔥' });
  a.send({ t: 'react', e: '💩' });
  assert.equal((await tv.wait('react')).e, '🔥');
  await new Promise((r) => setTimeout(r, 200));
  assert.ok(!(await tv.wait('react', 200).catch(() => null)));
  step('Réaction : relayée ; une réaction hors de la liste est ignorée');

  for (let i = 0; i < 4; i++) a.send({ t: 'chat', text: 'm' + i });
  for (let i = 0; i < 4; i++) await tv.wait('chat');
  a.send({ t: 'chat', text: 'de trop' });
  assert.equal((await a.wait('error')).code, 'slow');
  for (let i = 0; i < 10; i++) b.send({ t: 'react', e: '👏' });
  await new Promise((r) => setTimeout(r, 300));
  let n = 0;
  while (await tv.wait('react', 100).catch(() => null)) n++;
  assert.equal(n, 6);
  step('Limites : 5 messages par 10 s, 6 réactions par 2 s et par joueur');

  const late = await client(PORT);
  late.send({ t: 'join', code, name: 'Carla', emoji: '🐼', color: 3, photo: '' });
  await late.wait('joined');
  const log = (await late.wait('chat_log')).items;
  assert.equal(log.length, 5);
  assert.equal(log.at(-1).text, 'm3');
  step('Qui arrive en cours reçoit les derniers messages');

  // Dessin : pas de messages pendant qu'on devine (besoin des mots en base)
  if (process.env.PB_DB_URL) {
    a.send({ t: 'select_game', game: 'dessin' });
    a.send({ t: 'start_game' });
    const st = await tv.room((r) => r.game?.phase === 'choose', 8000);
    const drawer = st.room.game.drawer;
    const who = { [ja.pid]: a }[drawer] ?? (await (async () => {
      // le dessinateur n'est pas Alice : on cherche son téléphone
      const ids = Object.fromEntries(st.room.players.map((p) => [p.pid, p.name]));
      return { Bob: b, Carla: late }[ids[drawer]];
    })());
    who.send({ t: 'game_msg', m: { t: 'dsn_choose', i: 0 } });
    await tv.room((r) => r.game?.phase === 'draw', 8000);
    const guesser = [late, b, a].find((c) => c !== who); // un joueur qui n'a pas encore écrit
    guesser.flush();
    guesser.send({ t: 'chat', text: 'c’est un chat !' });
    assert.equal((await guesser.wait('error')).code, 'no_chat');
    guesser.send({ t: 'react', e: '😂' });
    assert.equal((await tv.wait('react')).e, '😂');
    step('Dessin : messages refusés pendant qu’on devine, réactions acceptées');
  }
  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC :', e);
  process.exitCode = 1;
} finally {
  srv.kill();
  setTimeout(() => process.exit(), 200);
}
