// Équipes, soirée enchaînée, statistiques des salons permanents.
//   PB_DB_URL=postgresql://… node test/soiree.test.js   (sans base : les statistiques sont sautées)
import assert from 'node:assert/strict';
import pg from 'pg';
import { startServer, client } from './lib.js';

const PORT = 4193;
const srv = await startServer(PORT, { PB_FAST: '1', PB_ROOMS_PER_IP: '100' });
let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };
const R = async (c, cond, ms = 8000) => (await c.room(cond, ms)).room;
const g = (m) => ({ t: 'game_msg', m });

try {
  const tv = await client(PORT);
  tv.send({ t: 'tv_hello' });
  const { code } = await tv.wait('tv_ok');
  const ps = [];
  for (const name of ['Alice', 'Bob', 'Carla', 'Dan']) {
    const c = await client(PORT);
    c.send({ t: 'join', code, name, emoji: '🙂', color: 0, photo: '' });
    c.me = (await c.wait('joined')).pid;
    ps.push(c);
  }
  const [a, b, c, d] = ps;

  // ---- équipes ----
  b.send({ t: 'teams_set', on: true, count: 2 }); // pas l'hôte : ignoré
  a.send({ t: 'teams_set', on: true, count: 2 });
  let r = await R(tv, (r) => r.teams);
  const sizes = [0, 0];
  for (const p of r.players) sizes[p.team]++;
  assert.deepEqual(sizes, [2, 2], 'équipes équilibrées à l’activation');
  a.send({ t: 'team_name', i: 0, name: '  Famille   Dupont ' });
  b.send({ t: 'team_pick', i: 0 });
  c.send({ t: 'team_pick', i: 1 });
  d.send({ t: 'team_pick', i: 1 });
  a.send({ t: 'team_pick', i: 0 });
  r = await R(tv, (r) => r.teams?.names[0] === 'Famille Dupont' && r.players.every((p) => p.team === (['Alice', 'Bob'].includes(p.name) ? 0 : 1)));
  a.send({ t: 'team_pick', i: 7 }); // équipe qui n'existe pas
  const late = await client(PORT);
  late.send({ t: 'join', code, name: 'Eve', emoji: '🙂', color: 0, photo: '' });
  late.me = (await late.wait('joined')).pid;
  r = await R(tv, (r) => r.players.length === 5);
  assert.ok([0, 1].includes(r.players.find((p) => p.name === 'Eve').team));
  step('Équipes : activées par l’hôte (équilibrées), renommées, chacun choisit la sienne, un nouveau venu est placé');

  // ---- soirée enchaînée : calcul puis zoom ----
  a.send({ t: 'soiree_start', games: ['calcul', 'nimporte', 'zoom'] });
  r = await R(tv, (r) => r.soiree && r.game?.id === 'calcul');
  assert.deepEqual(r.soiree.games, ['calcul', 'zoom']);
  // Bob répond juste à la 1re question
  const q = (await R(tv, (r) => r.game?.phase === 'ask')).game;
  const v = Function(`return (${q.expr.replace(/×/g, '*').replace(/÷/g, '/').replace(/−/g, '-').replace(/(\d+)²/g, '($1*$1)').replace(/^(\d+) % de (\d+)$/, '$1*$2/100')})`)();
  b.send(g({ t: 'calc_answer', r: q.index, v }));
  await R(tv, (r) => r.game?.phase === 'reveal');
  a.send(g({ t: 'game_end' }));
  await R(tv, (r) => r.game?.phase === 'podium');
  a.send(g({ t: 'game_skip' }));
  r = await R(tv, (r) => r.soiree?.step === 'interlude');
  assert.equal(r.game, null);
  const bob = r.soiree.ranking.find((x) => x.pid === b.me);
  assert.ok(bob.score > 0 && bob.rank === 1, 'Bob en tête de la soirée');
  assert.ok(r.soiree.teams[0] > 0 && r.soiree.teams[1] === 0, 'points de l’équipe de Bob');
  assert.equal(r.teams.last.pts[0], bob.score);
  a.send({ t: 'start_game' }); // pas de partie à part pendant une soirée
  r = await R(tv, (r) => r.game?.id === 'zoom', 6000); // l'entracte passe tout seul
  assert.equal(r.soiree.index, 1);
  a.send(g({ t: 'game_end' }));
  await R(tv, (r) => r.game?.phase === 'podium');
  a.send(g({ t: 'game_skip' }));
  r = await R(tv, (r) => r.soiree?.step === 'final');
  a.send({ t: 'soiree_next' });
  r = await R(tv, (r) => !r.soiree && r.phase === 'lobby');
  step('Soirée enchaînée : jeux inconnus ignorés, entracte avec classement (joueurs et équipes), jeu suivant tout seul, podium final, retour au salon');

  // ---- arrêt d'une soirée par l'hôte ----
  a.send({ t: 'soiree_start', games: ['zoom', 'calcul'] });
  await R(tv, (r) => r.soiree && r.game?.id === 'zoom');
  a.send({ t: 'soiree_stop' });
  r = await R(tv, (r) => r.soiree?.step === 'final' && !r.game);
  assert.deepEqual(r.soiree.games, ['zoom']);
  a.send({ t: 'soiree_next' });
  await R(tv, (r) => !r.soiree);
  // arrêt pendant l'entracte : podium final aussi
  a.send({ t: 'soiree_start', games: ['zoom', 'calcul', 'zoom2'] });
  await R(tv, (r) => r.soiree && r.game?.id === 'zoom');
  a.send(g({ t: 'game_end' }));
  await R(tv, (r) => r.game?.phase === 'podium');
  a.send(g({ t: 'game_skip' }));
  await R(tv, (r) => r.soiree?.step === 'interlude');
  a.send({ t: 'soiree_stop' });
  r = await R(tv, (r) => r.soiree?.step === 'final');
  assert.deepEqual(r.soiree.games, ['zoom']);
  a.send({ t: 'soiree_next' });
  await R(tv, (r) => !r.soiree);
  step('Soirée arrêtée par l’hôte (pendant un jeu ou l’entracte) : podium final directement');

  for (const x of [tv, ...ps, late]) x.close();

  // ---- statistiques d'un salon permanent ----
  if (process.env.PB_DB_URL) {
    const sql = new pg.Pool({ connectionString: process.env.PB_DB_URL });
    await sql.query("delete from pb.pb_rooms where code = 'TESTSTATS'");
    const tv2 = await client(PORT);
    tv2.send({ t: 'perm_create', code: 'TESTSTATS', password: 'abcd' });
    await tv2.wait('tv_ok');
    const m = [];
    for (const name of ['Mamie', 'Papy']) {
      const x = await client(PORT);
      x.send({ t: 'join', code: 'TESTSTATS', password: 'abcd', name, emoji: '👵', color: 1, photo: '' });
      x.me = (await x.wait('joined')).pid;
      m.push(x);
    }
    m[0].send({ t: 'select_game', game: 'calcul' });
    m[0].send({ t: 'start_game' });
    const q2 = (await R(tv2, (r) => r.game?.phase === 'ask')).game;
    const v2 = Function(`return (${q2.expr.replace(/×/g, '*').replace(/÷/g, '/').replace(/−/g, '-').replace(/(\d+)²/g, '($1*$1)').replace(/^(\d+) % de (\d+)$/, '$1*$2/100')})`)();
    m[1].send(g({ t: 'calc_answer', r: q2.index, v: v2 }));
    await R(tv2, (r) => r.game?.phase === 'reveal');
    m[0].send(g({ t: 'game_end' }));
    await R(tv2, (r) => r.game?.phase === 'podium');
    m[0].send(g({ t: 'game_skip' }));
    await R(tv2, (r) => !r.game);
    await new Promise((res) => setTimeout(res, 300));
    tv2.send({ t: 'perm_stats' });
    const st = await tv2.wait('perm_stats');
    assert.equal(st.members[0].name, 'Papy');
    assert.ok(st.members[0].score > 0);
    const champ = st.champions.find((x) => x.game === 'calcul');
    assert.equal(champ.name, 'Papy');
    assert.equal(champ.wins, 1);
    assert.equal(champ.played, 2);
    m[0].send({ t: 'perm_stats' });
    assert.equal((await m[0].wait('perm_stats')).members.length, 2);
    await sql.query("delete from pb.pb_rooms where code = 'TESTSTATS'");
    await sql.end();
    for (const x of [tv2, ...m]) x.close();
    step('Statistiques du salon permanent : classement de tous les temps, champion de chaque jeu, pour l’écran et les joueurs');
  }

  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC :', e);
  process.exitCode = 1;
} finally {
  srv.kill();
  setTimeout(() => process.exit(), 200);
}
