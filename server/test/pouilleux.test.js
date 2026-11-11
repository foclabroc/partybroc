// Le Pouilleux : paquet, paires, pioche, ordre de la main, partie de robots (sans base).
//   PB_FAST=1 node test/pouilleux.test.js
process.env.PB_FAST = '1';
const assert = (await import('node:assert/strict')).default;
const { makeDeck, dropPairs, PouilleuxGame, isPouilleux } = await import('../src/games/pouilleux.js');
const { Room } = await import('../src/rooms.js');

let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const card = (id, r, s) => ({ id, r, s });

function offline(n) {
  const players = new Map();
  for (let i = 0; i < n; i++) players.set('p' + i, { pid: 'p' + i, connected: true, name: 'J' + i });
  const g = new PouilleuxGame({ players, hostPid: 'p0' }, { changed() {}, finished() {} }, {});
  g.schedule = () => {};
  return g;
}

try {
  {
    assert.equal(makeDeck(4).length, 31);
    assert.equal(makeDeck(6).length, 51);
    assert.ok(!makeDeck(4).some((c) => c.r === 'V' && c.s === 't'), 'pas de valet de trèfle');
    const h = [card(1, '9', 'c'), card(2, '9', 'p'), card(3, '9', 'k'), card(4, 'V', 'p'), card(5, 'R', 't'), card(6, 'R', 'p')];
    const pairs = dropPairs(h);
    assert.equal(pairs.length, 2, '9 rouges + rois noirs');
    assert.deepEqual(h.map((c) => c.id).sort(), [2, 4]);
    const g = offline(4);
    for (const pid of g.order) {
      const hand = g.hands.get(pid);
      assert.equal(dropPairs([...hand]).length, 0, 'plus de paires après la distribution');
    }
    const all = [...g.hands.values()].flat();
    assert.equal(all.filter(isPouilleux).length, 1);
    step('31 cartes (51 à 6), paires de même couleur, plus aucune paire après la distribution');
  }
  {
    const g = offline(3);
    g.order = ['a', 'b', 'c'];
    g.hands = new Map([['a', [card(1, '9', 'c'), card(2, '7', 'p')]], ['b', [card(3, '9', 'k'), card(4, 'V', 'p')]], ['c', [card(5, '8', 't')]]]);
    g.saved = [];
    g.phase = 'deal';
    g.cur = 0;
    g.nextTurn(false);
    assert.equal(g.current, 'a');
    assert.equal(g.target, 'b');
    g.onMessage({ pid: 'b' }, { t: 'pou_order', ids: [4, 3] });
    g.onMessage({ pid: 'b' }, { t: 'pou_shuffle' });
    assert.deepEqual(g.hands.get('b').map((c) => c.id), [3, 4], 'b est visé : sa main ne bouge plus');
    g.onMessage({ pid: 'c' }, { t: 'pou_order', ids: [5] });
    g.onMessage({ pid: 'a' }, { t: 'pou_order', ids: [2, 1] });
    assert.deepEqual(g.hands.get('a').map((c) => c.id), [2, 1], 'a range sa main');
    g.onMessage({ pid: 'a' }, { t: 'pou_order', ids: [2, 2] });
    assert.deepEqual(g.hands.get('a').map((c) => c.id), [2, 1], 'ordre invalide refusé');
    g.onMessage({ pid: 'a' }, { t: 'pou_order', ids: [1, 2] });
    g.onMessage({ pid: 'a' }, { t: 'pou_hover', i: 0 });
    assert.equal(g.publicState().hover, 0);
    g.onMessage({ pid: 'a' }, { t: 'pou_take', i: 0 });
    assert.deepEqual(g.event.pair.map((c) => c.id).sort(), [1, 3], 'a prend le 9♦ : paire de 9 rouges');
    assert.deepEqual(g.hands.get('a').map((c) => c.id), [2]);
    g.nextTurn();
    assert.equal(g.current, 'b', 'au tour de celui chez qui on a pioché');
    assert.equal(g.target, 'c');
    assert.ok(!JSON.stringify(g.publicState()).includes('"hand"'), 'pas de main dans l’état public');
    step('Ranger sa main, viser une place, piocher, paire, au tour du voisin');
  }
  for (const n of [2, 4, 7]) {
    const room = new Room('TEST');
    for (let i = 0; i < n; i++) room.addBot(i % 2 ? 'facile' : 'malin');
    room.selectedGame = 'pouilleux';
    let results = null;
    const end = room.endGame.bind(room);
    room.endGame = (r) => { results = r; end(r); };
    await room.startGame();
    const g = room.game;
    const t0 = Date.now();
    while (!results && Date.now() - t0 < 120000) await sleep(20);
    room.clearBots();
    assert.ok(results, `${n} robots : partie finie`);
    assert.ok(g.loser, 'un Pouilleux');
    assert.ok(g.hands.get(g.loser).some(isPouilleux), 'il a le valet de pique');
    assert.equal(results.find((r) => r.pid === g.loser).score, 0);
    assert.equal(results.filter((r) => r.score === 1000).length, 1);
    step(`${n} robots jusqu'au Pouilleux (${((Date.now() - t0) / 1000).toFixed(1)} s, gage : ${g.gage})`);
  }
  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exitCode = 1;
}
process.exit();
