// Vrai ou Bluff : consignes secrètes, écriture, votes (on peut changer d'avis), points, anecdote écartée.
//   PB_FAST=1 node test/bluff.test.js
process.env.PB_FAST = '1';
const assert = (await import('node:assert/strict')).default;
const { BluffGame, secrets, BLF } = await import('../src/games/bluff.js');
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
    for (let n = 2; n <= 9; n++) {
      const s = [...secrets(Array.from({ length: n }, (_, i) => 'p' + i)).values()];
      const v = s.filter((x) => x === 'v').length;
      assert.ok(v >= Math.floor(n / 2) && v <= Math.ceil(n / 2), `moitié-moitié à ${n}`);
      assert.ok(v > 0 && v < n, 'jamais tous pareils');
    }
    step('consignes : moitié vrais, moitié bluffs, jamais tous pareils');
  }
  {
    assert.ok(gameById('bluff')?.ready, 'au catalogue');
    const r = room(4);
    let finished = null;
    const g = await BluffGame.create(r, { ecriture: '60 s', vote: '20 s' }, { changed() {}, finished(res) { finished = res; } });
    g.start();
    assert.equal(g.playerState('p1').secret, g.secret.get('p1'), 'chacun voit sa consigne');
    assert.equal(g.publicState().truth, undefined);
    await until(() => g.phase === 'write');
    assert.equal(g.duration, 6000, '60 s pour écrire (÷10)');
    g.onMessage({ pid: 'p0' }, { t: 'blf_write', text: 'court' });
    assert.equal(g.written.size, 0, 'trop court refusé');
    const texts = ['J’ai déjà serré la main de Zidane', 'Je sais jongler avec 5 balles', 'J’ai dormi dans un igloo', 'J’ai gagné un concours de grimaces'];
    for (let i = 0; i < 3; i++) g.onMessage({ pid: 'p' + i }, { t: 'blf_write', text: texts[i], theme: i });
    assert.deepEqual(g.publicState().done.sort(), ['p0', 'p1', 'p2']);
    assert.equal(g.phase, 'write');
    g.onMessage({ pid: 'p3' }, { t: 'blf_write', text: texts[3], theme: 99 });
    await until(() => g.phase === 'ask');
    assert.equal(g.count, 4);
    const ask = g.publicState();
    for (const k of ['truth', 'picks']) assert.equal(ask[k], undefined, `${k} caché pendant le vote`);
    assert.ok(ask.text && ask.author, 'anecdote et auteur affichés');
    const { author, truth } = g.round;
    assert.equal(g.playerState(author).mine, true);
    assert.equal(g.playerState(author).secret, truth, 'l’auteur revoit sa consigne');
    const others = ['p0', 'p1', 'p2', 'p3'].filter((p) => p !== author);
    assert.equal(g.playerState(others[0]).secret, undefined, 'les autres ne la voient pas');
    g.onMessage({ pid: author }, { t: 'blf_vote', r: 0, v: 'v' });
    assert.equal(g.answers.has(author), false, 'l’auteur ne vote pas');
    const wrong = truth === 'v' ? 'b' : 'v';
    g.onMessage({ pid: others[0] }, { t: 'blf_vote', r: 0, v: wrong });
    g.onMessage({ pid: others[0] }, { t: 'blf_vote', r: 0, v: truth });
    assert.equal(g.answers.get(others[0]).v, truth, 'on peut changer d’avis');
    g.onMessage({ pid: others[1] }, { t: 'blf_vote', r: 0, v: wrong });
    g.onMessage({ pid: others[2] }, { t: 'blf_vote', r: 0, v: wrong });
    await sleep(80);
    assert.equal(g.phase, 'ask', 'pas de révélation avant la fin : l’auteur se défend');
    await until(() => g.phase === 'reveal');
    const rev = g.publicState();
    assert.equal(rev.truth, truth);
    assert.ok(g.gains.get(others[0]) >= BLF.goodPoints, 'bon vote : 500 + rapidité');
    assert.equal(g.gains.get(others[1]) ?? 0, 0);
    assert.equal(g.gains.get(author), 2 * BLF.fooledPoints, 'auteur : 100 par joueur trompé');
    step('écriture, vote modifiable, pas de révélation anticipée, points');
    // L'hôte écarte l'anecdote suivante
    await until(() => g.phase === 'ask' && g.index === 1);
    const dropped = g.round.text;
    g.onMessage({ pid: 'p1' }, { t: 'blf_drop' });
    assert.equal(g.round.text, dropped, 'seul l’hôte peut écarter');
    g.onMessage({ pid: 'p0' }, { t: 'blf_drop' });
    assert.equal(g.count, 3);
    assert.notEqual(g.round.text, dropped);
    assert.equal(g.index, 1);
    step('l’hôte écarte une anecdote : on passe à la suivante');
    await until(() => finished, 20000);
    assert.equal(finished.length, 4);
    step('partie jusqu’au podium');
  }
  {
    // Personne n'écrit : podium direct
    const r = room(3);
    let finished = null;
    const g = await BluffGame.create(r, {}, { changed() {}, finished(res) { finished = res; } });
    g.start();
    await until(() => g.phase === 'write');
    g.onMessage({ pid: 'p0' }, { t: 'game_skip' });
    assert.equal(g.phase, 'podium');
    step('aucune anecdote : podium');
  }
  console.log(`Vrai ou Bluff : ${ok} étapes OK`);
  process.exit(0);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exit(1);
}
