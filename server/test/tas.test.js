// Le tas de merde : carré, passage au voisin, taper, faux carré, pénalité, partie de robots (sans base).
//   PB_FAST=1 node test/tas.test.js
process.env.PB_FAST = '1';
const assert = (await import('node:assert/strict')).default;
const { makeDeck, carreOf, kilosOf, TasGame } = await import('../src/games/tas.js');
const { Room } = await import('../src/rooms.js');

let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const card = (id, r, s = 'c') => ({ id, r, s });

function offline(n) {
  const players = new Map();
  for (let i = 0; i < n; i++) players.set('p' + i, { pid: 'p' + i, connected: true, name: 'J' + i });
  const g = new TasGame({ players, hostPid: 'p0' }, { changed() {}, finished() {} }, { manches: 3 });
  g.schedule = () => {};
  return g;
}

try {
  {
    assert.equal(makeDeck(4).length, 52);
    assert.equal(makeDeck(12).length, 104);
    assert.equal(carreOf([card(1, '9'), card(2, '9'), card(3, '9'), card(4, '9')]), '9');
    assert.equal(carreOf([card(1, '9'), card(2, '9'), card(3, '9'), card(4, 'R')]), null);
    assert.equal(kilosOf(card(1, 'A')) + kilosOf(card(2, 'R')) + kilosOf(card(3, '8')), 29, 'as 11, roi 10, 8');
    const g = offline(5);
    g.deal();
    const ranks = new Map();
    for (const c of [...g.hands.values()].flat()) ranks.set(c.r, (ranks.get(c.r) || 0) + 1);
    assert.equal(ranks.size, 5);
    assert.ok([...ranks.values()].every((k) => k === 4), '4 cartes de chaque valeur en jeu');
    assert.equal(g.pile.length, 32);
    step('52 cartes (104 au-delà de 10), une valeur par joueur en jeu, carré, kilos');
  }
  {
    const g = offline(3);
    g.order = ['a', 'b', 'c'];
    g.kilos = new Map([['a', 0], ['b', 0], ['c', 0]]);
    g.room.players = new Map(g.order.map((pid) => [pid, { pid, connected: true }]));
    g.deal();
    g.hands = new Map([
      ['a', [card(1, '9'), card(2, '9'), card(3, '9'), card(4, 'R')]],
      ['b', [card(5, '9'), card(6, '2'), card(7, '3'), card(8, '4')]],
      ['c', [card(9, 'R'), card(10, '5'), card(11, '6'), card(12, '7')]],
    ]);
    g.pickPhase();
    g.onMessage({ pid: 'a' }, { t: 'tas_pick', id: 4 });
    g.onMessage({ pid: 'b' }, { t: 'tas_pick', id: 5 });
    g.onMessage({ pid: 'c' }, { t: 'tas_pick', id: 9 });
    g.swap();
    assert.deepEqual(g.hands.get('b').map((c) => c.id).sort((x, y) => x - y), [4, 6, 7, 8], 'b reçoit le roi de a');
    assert.deepEqual(g.hands.get('c').map((c) => c.id).sort((x, y) => x - y), [5, 10, 11, 12], 'c reçoit le 9 de b');
    assert.equal(g.playerState('b').got, 4);
    g.onMessage({ pid: 'b' }, { t: 'tas_tap' });
    assert.equal(g.kilos.get('b'), 2, 'faux carré : 2 kilos');
    assert.equal(g.phase, 'swap');
    // a n'a pas de carré (il a passé son roi et reçu le roi de c : 3 neufs + roi)
    g.hands.get('a').splice(0, 4, card(1, '9'), card(2, '9'), card(3, '9'), card(13, '9', 'p'));
    g.pile = [card(20, '8')];
    g.onMessage({ pid: 'a' }, { t: 'tas_tap' });
    assert.equal(g.phase, 'tap');
    assert.equal(g.publicState().carre.length, 4);
    g.onMessage({ pid: 'c' }, { t: 'tas_tap' });
    g.penalty();
    assert.deepEqual(g.draws.map((d) => d.pid), ['b'], 'b n’a pas tapé');
    assert.equal(g.kilos.get('b'), 10, '2 + un 8');
    assert.ok(!JSON.stringify(g.publicState()).includes('"hand"'), 'pas de main dans l’état public');
    step('Passer au voisin, faux carré, carré, taper, le retardataire pioche');
  }
  {
    const g = offline(3);
    g.order = ['a', 'b', 'c'];
    g.room.players = new Map(g.order.map((pid) => [pid, { pid, connected: true }]));
    g.kilos = new Map([['a', 0], ['b', 23], ['c', 0]]);
    g.deal();
    g.hands.set('a', [card(1, 'D'), card(2, 'D', 'p'), card(3, 'D', 'k'), card(4, 'D', 't')]);
    g.pickPhase();
    g.onMessage({ pid: 'a' }, { t: 'tas_tap' });
    g.onMessage({ pid: 'c' }, { t: 'tas_tap' });
    g.onMessage({ pid: 'b' }, { t: 'tas_tap' });
    g.pile = [card(30, '7', 't')];
    g.penalty();
    assert.equal(g.draws[0].pid, 'b', 'le dernier à taper');
    assert.ok(g.draws[0].flush);
    assert.equal(g.kilos.get('b'), 0, 'chasse d’eau');
    g.manche = 3;
    g.end();
    assert.equal(g.scores.get('a'), 1000);
    assert.equal(g.scores.get('b'), 1000, 'ex æquo');
    step('Le dernier à taper pioche, le 7 vide ses kilos, classement au moins de kilos');
  }
  for (const n of [3, 6, 11]) {
    const room = new Room('TEST');
    for (let i = 0; i < n; i++) room.addBot(i % 2 ? 'facile' : 'malin');
    room.selectedGame = 'tas';
    room.options.tas = { manches: 3 };
    let results = null;
    const end = room.endGame.bind(room);
    room.endGame = (r) => { results = r; end(r); };
    await room.startGame();
    const g = room.game;
    const t0 = Date.now();
    while (!results && Date.now() - t0 < 120000) await sleep(20);
    room.clearBots();
    assert.ok(results, `${n} robots : partie finie`);
    assert.equal(g.manche, 3);
    assert.ok(results.some((r) => r.score === 1000));
    step(`${n} robots, 3 manches (${((Date.now() - t0) / 1000).toFixed(1)} s, kilos : ${[...g.kilos.values()].join(' ')})`);
  }
  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exitCode = 1;
}
process.exit();
