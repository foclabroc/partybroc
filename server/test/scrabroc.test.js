// Scrabroc : dictionnaire, calcul des points, règles de pose, partie de robots (sans base).
//   PB_FAST=1 node test/scrabroc.test.js
process.env.PB_FAST = '1';
const assert = (await import('node:assert/strict')).default;
const { evaluate, dict, makeBag, ScrabrocGame } = await import('../src/games/scrabroc.js');
const { Room } = await import('../src/rooms.js');

let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const empty = () => Array.from({ length: 15 }, () => Array(15).fill(null));
const word = (w, r, c, dr = 0, dc = 1) => [...w].map((l, i) => ({ r: r + dr * i, c: c + dc * i, l, j: false }));

try {
  {
    const d = dict();
    assert.ok(d.size > 300000);
    for (const w of ['MAISON', 'CHANTERONS', 'QI', 'KA', 'ZEN', 'FJORD', 'WHISKY']) assert.ok(d.has(w), w);
    assert.ok(!d.has('MAISONX'));
    assert.equal(makeBag(2).length, 102);
    assert.equal(makeBag(5).length, 204);
    step(`Dictionnaire : ${d.size} mots ; sac de 102 jetons (204 au-delà de 4 joueurs)`);
  }
  {
    const b = empty();
    let ev = evaluate(b, word('MAISON', 7, 5));
    assert.ok(ev.ok);
    assert.equal(ev.total, 14, 'MAISON sur l’étoile : 7 × 2');
    assert.equal(evaluate(b, word('MAISON', 6, 5)).err, 'Le premier mot passe par l’étoile');
    assert.match(evaluate(b, word('MAISONX', 7, 5)).err, /mot inconnu/);
    word('MAISON', 7, 5).forEach((p) => { b[p.r][p.c] = { l: p.l, j: false }; });
    // S à la fin de MAISON + mot vertical
    ev = evaluate(b, [{ r: 7, c: 11, l: 'S', j: false }]);
    assert.ok(ev.ok);
    assert.equal(ev.words[0].w, 'MAISONS');
    assert.match(evaluate(b, word('ZEN', 0, 0)).err, /toucher/);
    assert.match(evaluate(b, [{ r: 6, c: 5, l: 'E', j: false }, { r: 8, c: 6, l: 'E', j: false }]).err, /même ligne/);
    // Joker : vaut 0
    ev = evaluate(b, [{ r: 8, c: 5, l: 'E', j: true }]);
    assert.ok(ev.ok, ev.err);
    assert.equal(ev.words[0].w, 'ME');
    assert.equal(ev.total, 2, 'ME avec un joker E : M seulement');
    step('Points (étoile ×2, joker = 0), premier mot, mot inconnu, mots croisés, alignement');
  }
  {
    const players = new Map([['a', { pid: 'a', connected: true, name: 'A' }], ['b', { pid: 'b', connected: true, name: 'B' }]]);
    const sent = [];
    const g = new ScrabrocGame({ players, hostPid: 'a' }, { changed() {}, finished() {}, sendTo: (to, m) => sent.push([to, m]) }, {});
    g.schedule = () => {};
    g.order = ['a', 'b'];
    g.nextTurn();
    g.racks.set('a', ['M', 'A', 'I', 'S', 'O', 'N', '?']);
    g.onMessage({ pid: 'a' }, { t: 'scr_check', key: 1, tiles: [0, 1, 2, 3, 4, 5].map((i) => ({ r: 7, c: 5 + i, i })) });
    assert.equal(sent.at(-1)[1].t, 'scr_preview');
    assert.equal(sent.at(-1)[1].total, 14);
    g.onMessage({ pid: 'a' }, { t: 'scr_play', tiles: [0, 1, 2, 3, 4, 5, 6].map((i) => ({ r: 7, c: 5 + i, i, l: 'S' })) });
    assert.equal(g.points.get('a'), 14 + 50, 'MAISONS avec le joker S : 14 + 50 (7 lettres)');
    assert.equal(g.racks.get('a').length, 7);
    assert.equal(g.current, 'b');
    g.onMessage({ pid: 'b' }, { t: 'scr_play', tiles: [{ r: 0, c: 0, i: 0 }] });
    assert.equal(sent.at(-1)[1].t, 'scr_refused');
    assert.equal(g.current, 'b', 'coup refusé : toujours à B');
    step('Aperçu du coup, joker choisi, 7 lettres +50, coup refusé sans perdre son tour');
  }
  {
    const room = new Room('TEST');
    room.addBot('malin');
    room.addBot('facile');
    room.selectedGame = 'scrabroc';
    let results = null;
    const end = room.endGame.bind(room);
    room.endGame = (r) => { results = r; end(r); };
    await room.startGame();
    const g = room.game;
    const t0 = Date.now();
    while (!results && Date.now() - t0 < 240000) await sleep(50);
    room.clearBots();
    assert.ok(results, 'partie de robots finie');
    const words = g.hist.length;
    assert.ok(results.some((r) => r.score > 100), JSON.stringify(results));
    step(`2 robots jusqu'au podium en ${((Date.now() - t0) / 1000).toFixed(0)} s (scores ${results.map((r) => r.score).join(' / ')}, ${words} derniers coups gardés)`);
  }
  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exitCode = 1;
}
process.exit();
