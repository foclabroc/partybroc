// Petits chevaux : sortie sur un 6, prise, escalier à la française, équipes, partie complète.
//   PB_FAST=1 node test/chevaux.test.js
process.env.PB_FAST = '1';
const assert = (await import('node:assert/strict')).default;
const { ChevauxGame, CHV, START, LAST, END, cellOf, colorsFor } = await import('../src/games/chevaux.js');
const { gameById } = await import('../src/games/index.js');

let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const until = async (f, ms = 6000) => { const t = Date.now(); while (!f()) { if (Date.now() - t > ms) throw new Error('délai dépassé'); await sleep(5); } };

function room(n) {
  const players = new Map();
  for (let i = 0; i < n; i++) players.set('p' + i, { pid: 'p' + i, connected: true, name: 'J' + i });
  return { players, hostPid: 'p0', used: {} };
}
const hooks = (o = {}) => ({ changed() {}, finished(r) { o.res = r; } });

try {
  {
    assert.ok(gameById('chevaux')?.ready && gameById('chevaux').bots, 'au catalogue, avec robots');
    assert.deepEqual(colorsFor(2), [0, 2], 'à deux : face à face');
    assert.equal(cellOf(1, 0), START[1]);
    assert.equal(cellOf(0, LAST), 55);
    assert.equal(cellOf(0, LAST + 1), null, 'escalier hors du parcours');
    const g = await ChevauxGame.create(room(2), {}, hooks());
    g.horses = [[-1, -1, -1, -1], [-1, -1, -1, -1]];
    assert.equal(g.moves(0, 5).length, 0, 'il faut un 6 pour sortir');
    assert.equal(g.moves(0, 6).length, 1, 'un seul choix pour sortir (chevaux identiques)');
    // Prise : le rouge (couleur 2, départ 28) est sur la case 30 du parcours ; le vert arrive dessus
    g.horses = [[26, -1, -1, -1], [2, -1, -1, -1]];
    const m = g.moves(0, 4)[0];
    assert.equal(cellOf(0, 30), 30);
    assert.deepEqual(m.eat, { t: 1, h: 0 });
    step('sortie sur un 6, prise d’un cheval adverse');
  }
  {
    const g = await ChevauxGame.create(room(2), { arrivee: 'Escalier' }, hooks());
    g.horses = [[LAST - 2, -1, -1, -1], [-1, -1, -1, -1]];
    assert.equal(g.moves(0, 3).length, 0, 'on ne dépasse pas la case devant l’escalier');
    assert.equal(g.moves(0, 2)[0].to, LAST);
    g.horses[0][0] = LAST;
    assert.equal(g.moves(0, 2).length, 0, 'première marche : il faut un 1');
    assert.equal(g.moves(0, 1)[0].to, LAST + 1);
    g.horses[0][0] = LAST + 3;
    assert.equal(g.moves(0, 4)[0].to, LAST + 4, 'marche 3 → 4 avec un 4');
    g.horses[0][0] = LAST + 6;
    assert.equal(g.moves(0, 6)[0].to, END, 'un 6 pour entrer au centre');
    assert.equal(g.moves(0, 5).length, 0);
    const r = await ChevauxGame.create(room(2), { arrivee: 'Rapide' }, hooks());
    r.horses = [[LAST - 2, -1, -1, -1], [-1, -1, -1, -1]];
    assert.equal(r.moves(0, 5)[0].to, LAST + 3, 'rapide : on entre dans l’escalier avec n’importe quel dé');
    r.horses[0][0] = END - 2;
    assert.equal(r.moves(0, 3).length, 0, 'rapide : pile au centre');
    step('escalier à la française (1, 2… 6 puis 6) et arrivée rapide');
  }
  {
    // 6 joueurs : 4 couleurs, équipes de 1 ou 2, chacun son tour dans l'équipe
    const g = await ChevauxGame.create(room(6), { chevaux: 2 }, hooks());
    assert.deepEqual(g.colors, [0, 1, 2, 3]);
    assert.deepEqual(g.teams.map((t) => t.length).sort(), [1, 1, 2, 2]);
    assert.equal(g.horses[0].length, 2);
    const t = g.teams.findIndex((x) => x.length === 2);
    const a = g.pickPlayer(t), b = g.pickPlayer(t), c = g.pickPlayer(t);
    assert.notEqual(a, b);
    assert.equal(a, c, 'les membres d’une équipe lancent chacun leur tour');
    step('plus de 4 joueurs : équipes par couleur, chacun son tour');
  }
  {
    // Partie : lancer, choisir, rejouer sur un 6, podium
    const r = room(2);
    const o = {};
    const g = await ChevauxGame.create(r, { chevaux: 2, arrivee: 'Rapide' }, hooks(o));
    g.start();
    await until(() => g.phase === 'turn');
    const cur = g.player;
    const other = cur === 'p0' ? 'p1' : 'p0';
    g.onMessage({ pid: other }, { t: 'chv_roll' });
    assert.equal(g.die, null, 'pas à toi de lancer');
    assert.equal(g.playerState(cur).myTurn, true);
    g.onMessage({ pid: cur }, { t: 'chv_roll' });
    assert.ok(g.die >= 1 && g.die <= 6);
    assert.equal(g.phase, 'move');
    // On fait gagner la couleur en cours : chevaux presque arrivés, un choix à faire
    await until(() => g.phase === 'turn');
    const t = g.turn;
    g.horses[t] = [END - 1, END - 2];
    g.die = null;
    const realDie = Math.random;
    let forced = 1;
    const crypto = await import('node:crypto');
    const orig = crypto.default.randomInt;
    crypto.default.randomInt = (a, b) => (b === 7 ? forced : orig(a, b));
    g.onMessage({ pid: g.player }, { t: 'chv_roll' });
    assert.equal(g.phase, 'pick', 'deux chevaux peuvent bouger : on choisit');
    assert.equal(g.publicState().options.length, 2);
    g.onMessage({ pid: g.player }, { t: 'chv_pick', h: 0 });
    assert.equal(g.horses[t][0], END);
    await until(() => g.phase === 'turn');
    await until(() => g.phase === 'turn' && g.turn === t, 8000);
    forced = 2;
    g.onMessage({ pid: g.player }, { t: 'chv_roll' });
    crypto.default.randomInt = orig;
    Math.random = realDie;
    assert.equal(g.winner, t);
    await until(() => o.res, 8000);
    const win = o.res.find((x) => g.teams[t].includes(x.pid));
    assert.equal(win.score, CHV.winPoints);
    step('lancer à son tour, choisir son cheval, gagner : podium');
  }
  console.log(`Petits chevaux : ${ok} étapes OK`);
  process.exit(0);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exit(1);
}
