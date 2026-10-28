// Test de bout en bout du salon : lance le serveur, simule une TV et des téléphones.
// npm test   (avec PB_DB_URL pour tester aussi l'historique)
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { WebSocket } from 'ws';

const PORT = 4199;
const URL = `ws://127.0.0.1:${PORT}/ws`;

const srv = spawn(process.execPath, ['src/index.js'], {
  env: { ...process.env, PB_PORT: String(PORT) }, stdio: ['ignore', 'pipe', 'inherit'],
});
await new Promise((ok) => srv.stdout.on('data', (d) => { process.stdout.write('  srv> ' + d); if (/PartyBroc sur/.test(d)) ok(); }));

function client() {
  const ws = new WebSocket(URL);
  const inbox = [];
  const waiters = [];
  ws.on('message', (d) => {
    const m = JSON.parse(d);
    const i = waiters.findIndex((w) => w.pred(m));
    if (i >= 0) waiters.splice(i, 1)[0].ok(m); else inbox.push(m);
  });
  const c = {
    ws,
    open: () => new Promise((ok) => ws.on('open', ok)),
    send: (m) => ws.send(JSON.stringify(m)),
    wait: (pred, ms = 2000) => {
      const f = typeof pred === 'string' ? (m) => m.t === pred : pred;
      const i = inbox.findIndex(f);
      if (i >= 0) return Promise.resolve(inbox.splice(i, 1)[0]);
      return new Promise((ok, ko) => {
        const w = { pred: f, ok };
        waiters.push(w);
        setTimeout(() => { const j = waiters.indexOf(w); if (j >= 0) { waiters.splice(j, 1); ko(new Error('timeout ' + pred)); } }, ms);
      });
    },
    last: async (pred) => { await new Promise((r) => setTimeout(r, 150)); const all = inbox.filter(typeof pred === 'string' ? (m) => m.t === pred : pred); inbox.length = 0; return all.at(-1); },
    close: () => ws.close(),
  };
  return c;
}

// Petit JPEG valide (1x1)
const JPG = Buffer.from('/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==', 'base64').toString('base64');

let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };

try {
  // TV crée un salon
  const tv = client(); await tv.open();
  tv.send({ t: 'tv_hello' });
  const tvOk = await tv.wait('tv_ok');
  assert.match(tvOk.code, /^[BCDFGHJKLMNPQRSTVWXZ]{4}$/);
  step(`TV : salon ${tvOk.code} créé`);

  // Joueur 1 avec photo
  const a = client(); await a.open();
  a.send({ t: 'join', code: tvOk.code.toLowerCase(), name: '  Foc​  ', emoji: '🦊', color: 3, photo: JPG });
  const ja = await a.wait('joined');
  let room = (await tv.last('room')).room;
  assert.equal(room.players.length, 1);
  assert.equal(room.players[0].name, 'Foc');
  assert.equal(room.hostPid, ja.pid);
  assert.ok(room.players[0].photo);
  step('Joueur 1 rejoint (code en minuscules, pseudo nettoyé), devient hôte, photo acceptée');

  // La photo est servie en HTTP
  const r = await fetch(`http://127.0.0.1:${PORT}${room.players[0].photo}`);
  assert.equal(r.status, 200);
  assert.equal(r.headers.get('content-type'), 'image/jpeg');
  step('Photo servie par /a/…');

  // Pseudo en double refusé (accents/majuscules ignorés)
  const b = client(); await b.open();
  b.send({ t: 'join', code: tvOk.code, name: 'FÒC', emoji: '🐸' });
  assert.equal((await b.wait('error')).code, 'refused');
  step('Pseudo déjà pris refusé');

  // Photo bidon refusée
  b.send({ t: 'join', code: tvOk.code, name: 'Lulu', photo: Buffer.from('<svg>').toString('base64') });
  assert.equal((await b.wait('error')).code, 'bad_profile');
  step('Faux fichier image refusé');

  // Joueur 2 sans photo
  b.send({ t: 'join', code: tvOk.code, name: 'Lulu', emoji: '🐸', color: 7 });
  const jb = await b.wait('joined');
  room = (await tv.last('room')).room;
  assert.equal(room.players.length, 2);
  assert.equal(room.players[1].photo, null);
  step('Joueur 2 rejoint sans photo (emoji)');

  // Mauvais code
  const x = client(); await x.open();
  x.send({ t: 'join', code: 'ZZZZ', name: 'X' });
  assert.equal((await x.wait('error')).code, 'no_room');
  x.close();
  step('Code inconnu refusé');

  // Changement de profil
  b.send({ t: 'profile', name: 'Lulu la best', photo: JPG });
  await b.wait('profile_ok');
  room = (await tv.last('room')).room;
  assert.equal(room.players[1].name, 'Lulu la best');
  assert.match(room.players[1].photo, /\/1$/);
  step('Profil modifié (pseudo + photo)');

  // Coupure réseau du joueur 2 puis retour avec son jeton
  b.close();
  room = (await tv.wait((m) => m.t === 'room' && m.room.players.some((p) => !p.connected))).room;
  assert.equal(room.players.find((p) => p.pid === jb.pid).connected, false);
  const b2 = client(); await b2.open();
  b2.send({ t: 'resume', code: tvOk.code, token: jb.token });
  assert.equal((await b2.wait('joined')).pid, jb.pid);
  step('Joueur 2 coupé puis revenu à sa place');

  // L'hôte part : le joueur 2 devient hôte
  a.close();
  room = (await tv.wait((m) => m.t === 'room' && m.room.hostPid === jb.pid)).room;
  step("L'hôte coupe : le suivant devient hôte");

  // Hôte : choix du jeu, lancement d'un jeu pas prêt
  b2.send({ t: 'select_game', game: 'dessin' });
  room = (await tv.wait((m) => m.t === 'room' && m.room.selectedGame === 'dessin')).room;
  b2.send({ t: 'start_game' });
  assert.equal((await b2.wait('error')).code, 'not_enough');
  step("Choix du jeu par l'hôte, pas assez de joueurs pour le Dessin bien signalé");

  // Expulsion
  const c = client(); await c.open();
  c.send({ t: 'join', code: tvOk.code, name: 'Intrus' });
  const jc = await c.wait('joined');
  b2.send({ t: 'kick', pid: jc.pid });
  await c.wait('kicked');
  c.send({ t: 'resume', code: tvOk.code, token: jc.token });
  assert.equal((await c.wait('error')).code, 'expired');
  step("Expulsion par l'hôte, impossible de revenir avec l'ancien jeton");

  // La TV recharge la page : même salon
  tv.close();
  const tv2 = client(); await tv2.open();
  tv2.send({ t: 'tv_hello', code: tvOk.code, tvToken: tvOk.tvToken });
  assert.equal((await tv2.wait('tv_ok')).code, tvOk.code);
  step('TV rechargée : elle retrouve son salon');

  // Faux jeton TV : nouveau salon
  const tv3 = client(); await tv3.open();
  tv3.send({ t: 'tv_hello', code: tvOk.code, tvToken: 'faux' });
  assert.notEqual((await tv3.wait('tv_ok')).code, tvOk.code);
  step("Faux jeton TV : pas d'accès au salon, nouveau salon créé");

  // Salon complet : on remplit jusqu'au refus, qui doit arriver à 15 joueurs
  const many = [];
  let refusedAt = null;
  for (let i = 0; i < 20 && refusedAt === null; i++) {
    const k = client(); await k.open();
    k.send({ t: 'join', code: tvOk.code, name: 'J' + i });
    many.push(k);
    const m = await k.wait((x) => x.t === 'joined' || x.t === 'error');
    if (m.t === 'error') { assert.equal(m.code, 'refused'); refusedAt = m; }
  }
  const full = await tv2.last('room');
  assert.ok(refusedAt, 'un joueur doit être refusé');
  assert.equal(full.room.players.length, 15);
  step('16e joueur refusé (15 max)');

  const h = await (await fetch(`http://127.0.0.1:${PORT}/health`)).json();
  console.log('  /health', h);

  for (const k of [...many, b2, c, tv2, tv3]) k.close();
  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exitCode = 1;
} finally {
  srv.kill('SIGTERM');
}
