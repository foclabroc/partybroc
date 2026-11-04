// Robots : chaque jeu de société joué jusqu'au podium par des robots seuls,
// robots mis de côté pendant un jeu fun, jamais hôtes (sans base).
//   PB_FAST=1 node test/robots.test.js
process.env.PB_FAST = '1';
const assert = (await import('node:assert/strict')).default;
const { Room } = await import('../src/rooms.js');

let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function playAlone(game, levels, opts = {}) {
  const room = new Room('TEST');
  room.broadcastCount = 0;
  for (const l of levels) room.addBot(l);
  room.selectedGame = game;
  Object.assign(room.options[game], opts);
  let results = null;
  const end = room.endGame.bind(room);
  room.endGame = (r) => { results = r; end(r); };
  await room.startGame();
  const t0 = Date.now();
  while (!results && Date.now() - t0 < 120000) await sleep(20);
  room.clearBots();
  assert.ok(results, `${game} : la partie n'est pas allée jusqu'au bout`);
  return { room, results, ms: Date.now() - t0 };
}

try {
  {
    const room = new Room('TEST');
    const human = room.addPlayer({ name: 'Ana', emoji: '🙂', color: 0, photo: null });
    human.ws = { readyState: 3, send() {} };
    const b1 = room.addBot('malin');
    const b2 = room.addBot('facile');
    assert.equal(room.hostPid, human.pid);
    assert.equal(b1.name, 'Robert');
    assert.equal(b2.name, 'Bobette');
    assert.equal(room.view().players.find((p) => p.pid === b1.pid).bot, 'malin');
    // L'humain s'en va : aucun robot ne devient hôte, et le salon est vide pour le ménage
    human.ws = null;
    room.hostPid = null;
    room.pickHost();
    assert.equal(room.hostPid, null);
    assert.ok(room.isIdle(), 'les robots ne gardent pas le salon ouvert');
    human.ws = { readyState: 3, send() {} };
    room.pickHost();
    assert.equal(room.hostPid, human.pid);
    // Jeu fun : les robots attendent de côté, puis reviennent
    room.selectedGame = 'calcul';
    await room.startGame();
    assert.equal(room.players.size, 1);
    assert.equal(room.bench.size, 2);
    room.endGame([]);
    assert.equal(room.players.size, 3);
    assert.equal(room.bench.size, 0);
    assert.equal(room.view().games.find((g) => g.id === 'calcul').bots, false);
    assert.equal(room.view().games.find((g) => g.id === 'yams').bots, true);
    room.options.loto.mode = 'Cartons papier';
    assert.equal(room.view().games.find((g) => g.id === 'loto').bots, false);
    step('Robots ajoutés (Robert, Bobette), jamais hôtes, de côté pendant un jeu fun');
  }
  for (const [game, levels, opts] of [
    ['serpents', ['malin', 'facile'], { arrivee: 'Dès 100' }],
    ['oie', ['malin', 'facile', 'malin'], {}],
    ['yams', ['malin', 'facile'], {}],
    ['pioche', ['malin', 'facile', 'malin'], { cards: 5 }],
    ['loto', ['malin', 'facile'], { vitesse: 'Rapide', marquage: 'À la main' }],
  ]) {
    const { results, ms } = await playAlone(game, levels, opts);
    assert.equal(results.length, levels.length);
    assert.ok(results.some((r) => r.score > 0), `${game} : personne n'a marqué`);
    step(`${game} joué par ${levels.length} robots jusqu'au podium (${(ms / 1000).toFixed(1)} s)`);
  }
  {
    // Yams : un robot Malin fait en moyenne bien mieux que de remplir les cases au hasard
    const totals = [];
    for (let i = 0; i < 2; i++) {
      const { results } = await playAlone('yams', ['malin']);
      totals.push(results[0].score);
    }
    const avg = totals.reduce((a, b) => a + b, 0) / totals.length;
    assert.ok(avg > 120, `Yams Malin : moyenne ${avg}`);
    step(`Yams Malin seul : ${totals.join(', ')} points`);
  }
  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exitCode = 1;
}
process.exit();
