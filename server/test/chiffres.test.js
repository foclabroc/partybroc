// Chiffres et lettres : tirage des lettres, mots vérifiés, calculs rejoués, points, partie complète.
//   PB_FAST=1 node test/chiffres.test.js
process.env.PB_FAST = '1';
const assert = (await import('node:assert/strict')).default;
const { ChiffresGame, CEL, forcedKind, drawLetter, fits, replay, solve, drawNumbers, nearPoints, VOWELS } = await import('../src/games/chiffres.js');
const { gameById } = await import('../src/games/index.js');

let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const until = async (f, ms = 4000) => { const t = Date.now(); while (!f()) { if (Date.now() - t > ms) throw new Error('délai dépassé'); await sleep(5); } };

function room(n) {
  const players = new Map();
  for (let i = 0; i < n; i++) players.set('p' + i, { pid: 'p' + i, connected: true, name: 'J' + i });
  return { players, hostPid: 'p0', used: {} };
}

try {
  {
    for (let k = 0; k < 200; k++) {
      const L = [];
      while (L.length < 9) L.push(drawLetter(L, 'c'));
      assert.ok(L.filter((l) => l in VOWELS).length >= 2, 'au moins 2 voyelles même en demandant que des consonnes');
      const M = [];
      while (M.length < 9) M.push(drawLetter(M, 'v'));
      assert.ok(M.filter((l) => !(l in VOWELS)).length >= 3, 'au moins 3 consonnes');
      for (const l of new Set(M)) assert.ok(M.filter((x) => x === l).length <= 3, 'pas plus de 3 fois la même lettre');
    }
    assert.equal(forcedKind(['B', 'C', 'D', 'F', 'G', 'H', 'J']), 'v');
    assert.ok(fits('PATRONS', [...'RNAOSPITU']));
    assert.ok(!fits('PATTE', [...'RNAOSPITU']), 'une lettre ne sert qu’une fois');
    step('tirage des lettres : 2 voyelles et 3 consonnes au moins, 3 fois la même au plus');
  }
  {
    assert.deepEqual(replay([25, 50, 6, 3, 7, 1], [[25, '*', 3], [50, '-', 1], [6, '+', 7], [49, '*', 13], [637, '+', 75]]).pool.includes(712), true);
    assert.equal(replay([25, 50, 6, 3, 7, 1], [[25, '*', 25]]), null, 'plaque utilisée deux fois');
    assert.equal(replay([25, 50, 6, 3, 7, 1], [[3, '-', 7]]), null, 'pas de négatif');
    assert.equal(replay([25, 50, 6, 3, 7, 1], [[7, '/', 3]]), null, 'division juste seulement');
    assert.equal(replay([25, 50, 6, 3, 7, 1], [[25, '+', 712]]), null, 'nombre inventé');
    for (let k = 0; k < 15; k++) {
      const d = drawNumbers();
      assert.ok(d.target >= 101 && d.target <= 999);
      const r = replay(d.plates, d.solution.map(([a, op, b]) => [a, op, b]));
      assert.ok(r && r.pool.includes(d.target), 'la solution du jeu tombe juste');
    }
    assert.equal(solve([1, 1, 1, 1, 1, 1], 999).d > 0, true, 'pas de solution : la plus proche');
    assert.equal(nearPoints(3), 300);
    assert.equal(nearPoints(30), 0);
    step('calculs rejoués et vérifiés, tirages toujours avec une solution exacte');
  }
  {
    assert.ok(gameById('chiffres')?.ready, 'au catalogue');
    const r = room(3);
    let finished = null;
    const sent = [];
    const g = await ChiffresGame.create(r, { rounds: 4, temps: '30 s' }, { changed() {}, finished(res) { finished = res; }, sendTo(to, m) { sent.push([to, m]); } });
    assert.deepEqual(g.kinds, ['L', 'C', 'L', 'C']);
    g.start();
    await until(() => g.phase === 'draw');
    assert.equal(g.round.drawer, 'p0');
    g.onMessage({ pid: 'p1' }, { t: 'cel_pick', k: 'v' });
    assert.equal(g.round.letters.length, 0, 'seul le tireur choisit');
    g.onMessage({ pid: 'p0' }, { t: 'cel_pick', k: 'v' });
    assert.ok(g.round.letters[0] in VOWELS);
    await until(() => g.phase === 'think', 6000); // le reste tiré tout seul
    assert.equal(g.round.letters.length, 9);
    // On impose un tirage connu pour vérifier les mots
    g.round.letters = [...'RNAOSPITU'];
    g.round.best = ['SOUPIRANT'];
    const pub = g.publicState();
    assert.equal(pub.best, undefined, 'meilleur mot caché pendant la recherche');
    g.onMessage({ pid: 'p0' }, { t: 'cel_word', r: 0, w: 'tapirs' });
    g.onMessage({ pid: 'p0' }, { t: 'cel_word', r: 0, w: 'Patrons' });
    g.onMessage({ pid: 'p0' }, { t: 'cel_word', r: 0, w: 'PAON' });
    assert.equal(g.answers.get('p0').w, 'PATRONS', 'on garde le plus long');
    g.onMessage({ pid: 'p1' }, { t: 'cel_word', r: 0, w: 'PIRATS' });
    g.onMessage({ pid: 'p1' }, { t: 'cel_word', r: 0, w: 'PATTES' });
    const res = sent.filter(([to]) => to === 'p1').map(([, m]) => m);
    assert.equal(res[0].err, 'Pas dans le dictionnaire');
    assert.equal(res[1].err, 'Pas avec ces lettres');
    g.onMessage({ pid: 'p2' }, { t: 'cel_word', r: 0, w: 'tapir' });
    assert.deepEqual(g.publicState().answered.sort(), ['p0', 'p2']);
    assert.equal(g.publicState().words, undefined, 'mots cachés pendant la recherche');
    g.onMessage({ pid: 'p0' }, { t: 'game_skip' });
    assert.equal(g.phase, 'reveal');
    assert.equal(g.gains.get('p0'), 7 * CEL.letterPoints + CEL.longestBonus);
    assert.equal(g.gains.get('p2'), 5 * CEL.letterPoints);
    assert.equal(g.publicState().words[0].w, 'PATRONS');
    step('lettres : seul le tireur choisit, mots vérifiés, le plus long gardé, points');
    await until(() => g.phase === 'think' && g.round.kind === 'C', 6000);
    g.round.plates = [25, 50, 6, 3, 7, 1];
    g.round.target = 712;
    g.onMessage({ pid: 'p1' }, { t: 'cel_calc', r: 1, steps: [[25, '*', 3], [50, '-', 1]] });
    assert.equal(g.answers.get('p1').v, 75);
    assert.equal(g.publicState().exact.length, 0);
    g.onMessage({ pid: 'p1' }, { t: 'cel_calc', r: 1, steps: [[25, '*', 3], [50, '-', 1], [6, '+', 7], [49, '*', 13], [637, '+', 75]] });
    assert.deepEqual(g.publicState().exact, ['p1']);
    g.onMessage({ pid: 'p2' }, { t: 'cel_calc', r: 1, steps: [[50, '+', 25], [75, '*', 7], [525, '+', 6]] });
    g.onMessage({ pid: 'p2' }, { t: 'cel_calc', r: 1, steps: [[50, '*', 6]] });
    assert.equal(g.answers.get('p2').v, 531, 'un résultat moins bon ne remplace pas le meilleur');
    assert.equal(g.playerState('p2').calc.d, 181);
    g.onMessage({ pid: 'p0' }, { t: 'cel_calc', r: 1, steps: [[7, '+', 1], [50, '+', 25], [75, '+', 6], [81, '+', 3], [84, '*', 8]] });
    assert.equal(g.answers.get('p0').v, 712 - 40);
    g.onMessage({ pid: 'p0' }, { t: 'game_skip' });
    const rv = g.publicState();
    assert.equal(rv.results[0].pid, 'p1');
    assert.equal(rv.solutionBy, 'p1');
    assert.ok(g.gains.get('p1') >= CEL.exactPoints);
    assert.equal(g.gains.get('p2') ?? 0, 0, 'trop loin : 0');
    step('chiffres : calculs rejoués, meilleur résultat gardé, solution du plus rapide, points');
    await until(() => finished, 20000);
    assert.equal(finished.length, 3);
    step('partie de 4 manches jusqu’au podium');
  }
  {
    const r = room(2);
    const g = await ChiffresGame.create(r, { mode: 'Chiffres seulement', rounds: 4 }, { changed() {}, finished() {}, sendTo() {} });
    assert.deepEqual(g.kinds, ['C', 'C', 'C', 'C']);
    g.start();
    await until(() => g.phase === 'think');
    const { plates, solution } = g.round;
    for (const p of ['p0', 'p1']) g.onMessage({ pid: p }, { t: 'cel_calc', r: 0, steps: solution.map(([a, op, b]) => [a, op, b]) });
    assert.deepEqual(plates.length, 6);
    await until(() => g.phase === 'reveal', 1500);
    step('tout le monde a trouvé pile : révélation sans attendre');
    g.stop();
  }
  console.log(`Chiffres et lettres : ${ok} étapes OK`);
  process.exit(0);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exit(1);
}
