// Salons permanents : création par un écran, mot de passe, joueurs retrouvés, score gardé,
// plusieurs écrans, blocage après trop d'essais.   PB_DB_URL=postgresql://… node test/perm.test.js
import assert from 'node:assert/strict';
import pg from 'pg';
import { startServer, client } from './lib.js';

if (!process.env.PB_DB_URL) { console.log('PB_DB_URL manquant : test des salons permanents ignoré'); process.exit(0); }

const PORT = 4197;
const NAME = 'TESTFAMILLE';
const sql = new pg.Pool({ connectionString: process.env.PB_DB_URL });
await sql.query('delete from pb.pb_rooms where code = $1', [NAME]);

let srv = await startServer(PORT, { PB_FAST: '1' });
let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };
// état du salon (et pas tout le message)
const R = async (c, cond, ms) => (await c.room(cond, ms)).room;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

try {
  // ---- création depuis la TV ----
  const tv = await client(PORT);
  tv.send({ t: 'perm_create', code: 'Test', password: 'abcd' });
  assert.equal((await tv.wait('error')).code, 'bad_name');
  tv.send({ t: 'perm_create', code: 'Test Famille', password: 'ab' });
  assert.equal((await tv.wait('error')).code, 'bad_pass');
  tv.send({ t: 'perm_create', code: 'Test Famillé', password: 'mamie59' });
  const created = await tv.wait('tv_ok');
  assert.equal(created.code, NAME);
  assert.equal(created.perm, true);
  assert.ok(created.key);
  const row = (await sql.query('select pass_hash from pb.pb_rooms where code = $1', [NAME])).rows[0];
  assert.match(row.pass_hash, /^scrypt\$/);
  assert.ok(!row.pass_hash.includes('mamie59'));
  const tv2 = await client(PORT);
  tv2.send({ t: 'perm_create', code: NAME, password: 'autre' });
  assert.equal((await tv2.wait('error')).code, 'name_taken');
  step('Créé depuis la TV : nom en lettres (accents enlevés), mot de passe chiffré, nom unique');

  // ---- téléphones ----
  const a = await client(PORT);
  a.send({ t: 'join', code: NAME, name: 'Mamie', emoji: '👵', color: 2, photo: '' });
  assert.equal((await a.wait('error')).code, 'need_pass');
  a.send({ t: 'join', code: NAME, password: 'faux', name: 'Mamie', emoji: '👵', color: 2, photo: '' });
  assert.equal((await a.wait('error')).code, 'bad_pass');
  a.send({ t: 'join', code: NAME.toLowerCase(), password: 'mamie59', name: 'Mamie', emoji: '👵', color: 2, photo: '' });
  const ja = await a.wait('joined');
  assert.ok(ja.mtoken && ja.perm);
  const b = await client(PORT);
  b.send({ t: 'join', code: NAME, password: 'mamie59', name: 'Papy', emoji: '👴', color: 4, photo: '' });
  const jb = await b.wait('joined');
  const r0 = await R(tv, (r) => r.players.length === 2);
  assert.equal(r0.perm, true);
  step('Joueurs : mot de passe demandé, refusé s\'il est faux, jeton de membre reçu');

  // ---- un 2e écran (la famille à distance) ----
  const far = await client(PORT);
  far.send({ t: 'perm_open', code: NAME, password: 'faux' });
  assert.equal((await far.wait('error')).code, 'bad_pass');
  far.send({ t: 'perm_open', code: NAME, password: 'mamie59' });
  const farOk = await far.wait('tv_ok');
  const both = await Promise.all([R(tv, (r) => r.players.length === 2), R(far, (r) => r.players.length === 2)]);
  assert.ok(both[0].tvConnected && both[1].tvConnected);
  step('Deuxième écran ouvert avec le mot de passe : les deux écrans reçoivent le salon');

  // ---- une partie : score gardé ----
  a.send({ t: 'select_game', game: 'reflexes' });
  a.send({ t: 'game_option', key: 'rounds', value: 3 });
  a.send({ t: 'start_game' });
  await R(far, (r) => r.game);
  a.send({ t: 'game_msg', m: { t: 'game_end' } });
  await R(tv, (r) => r.game?.phase === 'podium', 8000);
  a.send({ t: 'game_msg', m: { t: 'game_skip' } });
  await R(tv, (r) => !r.game);
  await sleep(300);
  const games = (await sql.query('select sum(games)::int as n from pb.pb_room_members where code = $1', [NAME])).rows[0].n;
  assert.equal(games, 2); // une partie de plus pour chacun des 2 joueurs
  step('Partie jouée dans le salon permanent, vue sur les deux écrans');

  // ---- tout le monde part, le serveur redémarre (salons en mémoire perdus) ----
  for (const c of [a, b, tv, tv2, far]) c.close();
  await new Promise((r) => { srv.once('exit', r); srv.kill(); });
  // des points à la main (serveur arrêté), pour vérifier qu'ils sont bien relus
  await sql.query("update pb.pb_room_members set score = 1234 where code = $1 and name = 'Mamie'", [NAME]);
  srv = await startServer(PORT, { PB_FAST: '1' });

  // l'écran revient avec sa clé, sans mot de passe
  const tvB = await client(PORT);
  tvB.send({ t: 'perm_open', code: NAME, key: 'mauvaise' });
  assert.equal((await tvB.wait('error')).code, 'need_pass');
  tvB.send({ t: 'perm_open', code: NAME, key: created.key });
  assert.equal((await tvB.wait('tv_ok')).code, NAME);

  // Mamie revient avec son jeton (sans mot de passe) : même joueur, score total retrouvé
  const a2 = await client(PORT);
  a2.send({ t: 'join', code: NAME, mtoken: ja.mtoken, name: 'Mamie Jo', emoji: '👵', color: 2, photo: '' });
  const ja2 = await a2.wait('joined');
  assert.equal(ja2.pid, ja.pid);
  assert.equal(ja2.mtoken, ja.mtoken);
  const r1 = await R(tvB, (r) => r.players.length === 1);
  assert.equal(r1.players[0].score, 1234);
  assert.equal(r1.players[0].name, 'Mamie Jo');
  step('Après redémarrage : écran revenu avec sa clé, joueur revenu avec son jeton, score total 1 234');

  // Papy change de téléphone (pas de jeton) : mot de passe + même pseudo = même joueur
  const b2 = await client(PORT);
  b2.send({ t: 'join', code: NAME, password: 'mamie59', name: 'papy', emoji: '👴', color: 4, photo: '' });
  const jb2 = await b2.wait('joined');
  assert.equal(jb2.pid, jb.pid);
  assert.notEqual(jb2.mtoken, undefined);
  // et l'ancien jeton de Papy ne marche plus
  const b3 = await client(PORT);
  b3.send({ t: 'join', code: NAME, mtoken: jb.mtoken, name: 'Autre', emoji: '🙂', color: 0, photo: '' });
  assert.equal((await b3.wait('error')).code, 'need_pass');
  step('Nouveau téléphone : retrouvé à son pseudo avec le mot de passe, ancien jeton remplacé');

  const row2 = (await sql.query("select emoji, color from pb.pb_room_members where code = $1 and member_id = $2", [NAME, ja.pid])).rows[0];
  assert.deepEqual(row2, { emoji: '👵', color: 2 });
  const cols = (await sql.query("select column_name from information_schema.columns where table_name = 'pb_room_members'")).rows.map((r) => r.column_name);
  assert.ok(!cols.some((c) => /photo/.test(c)));
  step('En base : pseudo, emoji, couleur, score ; aucune photo');

  // ---- trop d'essais ratés : bloqué, même avec le bon mot de passe ----
  const bad = await client(PORT);
  for (let i = 0; i < 8; i++) {
    bad.send({ t: 'join', code: NAME, password: 'x' + i, name: 'Pirate', emoji: '🙂', color: 0, photo: '' });
    await bad.wait('error');
  }
  bad.send({ t: 'join', code: NAME, password: 'mamie59', name: 'Pirate', emoji: '🙂', color: 0, photo: '' });
  assert.equal((await bad.wait('error')).code, 'blocked');
  step('8 mauvais mots de passe : bloqué un quart d\'heure');

  // ---- un salon permanent n'est pas fermé par « Nouveau salon » ----
  tvB.send({ t: 'tv_new' });
  const fresh = await tvB.wait('tv_ok');
  assert.match(fresh.code, /^[A-Z]{4}$/);
  await R(a2, (r) => r.code === NAME && !r.tvConnected);
  step('« Nouveau salon » sur la TV : le salon permanent reste ouvert pour les joueurs');

  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC :', e);
  process.exitCode = 1;
} finally {
  await sql.query('delete from pb.pb_rooms where code = $1', [NAME]);
  await sql.end();
  srv.kill();
  setTimeout(() => process.exit(), 200);
}
