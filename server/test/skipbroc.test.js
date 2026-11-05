// Skip-Broc : règles (piles 1 → 12, ★, talon, défausses) et partie complète par des robots (sans base).
//   PB_FAST=1 node test/skipbroc.test.js
process.env.PB_FAST = '1';
const assert = (await import('node:assert/strict')).default;
const { SkipBrocGame, makeDeck, fits } = await import('../src/games/skipbroc.js');
const { Room } = await import('../src/rooms.js');

let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function offline(n = 2, opts = {}) {
  const players = new Map();
  for (let i = 0; i < n; i++) players.set('p' + i, { pid: 'p' + i, connected: true, name: 'J' + i });
  const g = new SkipBrocGame({ players, hostPid: 'p0' }, { changed() {}, finished() {} }, opts);
  g.schedule = () => {};
  g.order = [...players.keys()];
  return g;
}

try {
  {
    const d = makeDeck(4);
    assert.equal(d.length, 162);
    assert.equal(d.filter((c) => c.v === 0).length, 18);
    assert.equal(makeDeck(8).length, 324);
    assert.ok(fits({ v: 1 }, []) && fits({ v: 0 }, []) && !fits({ v: 2 }, []));
    assert.ok(fits({ v: 3 }, [{}, {}]) && !fits({ v: 4 }, [{}, {}]));
    const g = offline(2, { talon: '10 cartes' });
    assert.equal(g.size, 10);
    assert.equal(g.stock.get('p0').length, 10);
    step('Paquet de 162 cartes (2 paquets au-delà de 6 joueurs), piles de 1 à 12, talon de 10');
  }
  {
    const g = offline(2);
    g.nextTurn();
    const pid = g.current;
    assert.equal(g.hands.get(pid).length, 5);
    // Une main sur mesure : 1, 2, ★ et deux 9 ; talon : 4
    g.hands.set(pid, [{ id: 901, v: 1 }, { id: 902, v: 2 }, { id: 903, v: 0 }, { id: 904, v: 9 }, { id: 905, v: 9 }]);
    g.stock.get(pid).push({ id: 906, v: 4 });
    assert.equal(g.play(pid, 'hand', 1, 0), false, 'un 2 ne commence pas une pile');
    assert.ok(g.play(pid, 'hand', 0, 0));
    assert.ok(g.play(pid, 'hand', 0, 0));
    assert.ok(g.play(pid, 'hand', 0, 0), 'le ★ vaut 3');
    assert.equal(g.builds[0][2].as, 3);
    assert.ok(g.play(pid, 'stock', 0, 0), 'le 4 du talon');
    assert.equal(g.builds[0].length, 4);
    assert.equal(g.play('p' + (pid === 'p0' ? 1 : 0), 'hand', 0, 1), false, 'pas son tour');
    // Défausse : on ne défausse que depuis la main, puis c'est au suivant
    const before = g.hands.get(pid).length;
    assert.ok(g.discard(pid, 0, 2));
    assert.equal(g.discs.get(pid)[2].length, 1);
    assert.equal(g.hands.get(pid).length, before - 1);
    assert.notEqual(g.current, pid);
    step('Tour : 1, 2, ★ = 3, 4 du talon, défausse, joueur suivant');
  }
  {
    const g = offline(2);
    g.nextTurn();
    const pid = g.current;
    g.builds[1] = Array.from({ length: 11 }, (_, k) => ({ id: 1000 + k, v: k + 1, as: k + 1 }));
    g.hands.set(pid, [{ id: 950, v: 12 }]);
    assert.ok(g.play(pid, 'hand', 0, 1));
    assert.equal(g.builds[1].length, 0, 'pile complète retirée');
    assert.equal(g.recycle.length, 12);
    assert.equal(g.hands.get(pid).length, 5, 'main vide : 5 nouvelles cartes');
    g.stock.set(pid, [{ id: 960, v: 1 }]);
    g.play(pid, 'stock', 0, 1);
    assert.equal(g.winner, pid);
    step('Pile à 12 retirée, main vide → 5 cartes, talon vide = gagné');
  }
  {
    const room = new Room('TEST');
    for (const l of ['malin', 'facile', 'malin']) room.addBot(l);
    room.selectedGame = 'skipbroc';
    room.options.skipbroc.talon = '10 cartes';
    let results = null;
    const end = room.endGame.bind(room);
    room.endGame = (r) => { results = r; end(r); };
    await room.startGame();
    const t0 = Date.now();
    while (!results && Date.now() - t0 < 120000) await sleep(20);
    room.clearBots();
    assert.ok(results, 'la partie de robots est allée au bout');
    assert.equal(results.filter((r) => r.score === 1000).length, 1);
    step(`3 robots jusqu'au podium (${((Date.now() - t0) / 1000).toFixed(1)} s)`);
  }
  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exitCode = 1;
}
process.exit();
