// Tests des jeux Qui de nous ?, Réponses drôles, Course de réflexes, Dessin à deviner
// (délais ÷10, base obligatoire). Les temps de réaction envoyés restent petits :
// le serveur les borne à « temps réellement écoulé + 300 ms ».   PB_DB_URL=postgresql://… node test/jeux.test.js
import assert from 'node:assert/strict';
import { startServer, client } from './lib.js';

if (!process.env.PB_DB_URL) { console.log('PB_DB_URL manquant : tests des jeux ignorés'); process.exit(0); }

const PORT = 4197;
const srv = await startServer(PORT, { PB_FAST: '1' });
let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function setup(names) {
  const tv = await client(PORT);
  tv.send({ t: 'tv_hello' });
  const { code } = await tv.wait('tv_ok');
  const ps = [];
  for (const name of names) {
    const c = await client(PORT);
    c.send({ t: 'join', code, name });
    c.pid = (await c.wait('joined')).pid;
    ps.push(c);
  }
  return { tv, ps, code };
}
const gm = (c, m) => c.send({ t: 'game_msg', m });
const live = (tv, cond, ms = 4000) => tv.room((r) => r.game && cond(r.game, r), ms);

try {
  // ================= Qui de nous ?
  {
    const { tv, ps } = await setup(['Ana', 'Ben', 'Cléo', 'Dan']);
    const [a, b, c, d] = ps;
    a.send({ t: 'select_game', game: 'quidenous' });
    a.send({ t: 'game_option', key: 'rounds', value: 5 });
    await tv.room((r) => r.selectedGame === 'quidenous' && r.options.rounds === 5);
    a.send({ t: 'start_game' });
    let g = (await live(tv, (g) => g.id === 'quidenous' && g.phase === 'vote' && g.index === 0)).room.game;
    assert.ok(g.prompt && g.count === 5);
    gm(a, { t: 'qdn_vote', r: 0, pid: a.pid }); // pour soi : refusé
    gm(a, { t: 'qdn_vote', r: 0, pid: c.pid });
    gm(b, { t: 'qdn_vote', r: 0, pid: c.pid });
    gm(c, { t: 'qdn_vote', r: 0, pid: d.pid });
    g = (await live(tv, (g) => g.phase === 'vote' && g.voted.length === 3)).room.game;
    assert.ok(!('tally' in g), 'votes cachés avant la révélation');
    assert.ok(!JSON.stringify(g).includes(`"${c.pid}":`), 'pas de « qui a voté pour qui »');
    gm(d, { t: 'qdn_vote', r: 0, pid: c.pid });
    g = (await live(tv, (g) => g.phase === 'reveal' && g.index === 0)).room.game;
    assert.deepEqual(g.winners, [c.pid]);
    assert.equal(g.tally[0].count, 3);
    const gainOf = (pid) => g.ranking.find((x) => x.pid === pid).gain;
    assert.equal(gainOf(a.pid), 100); assert.equal(gainOf(c.pid), 50); assert.equal(gainOf(d.pid), 100); assert.equal(gainOf(b.pid), 100);
    step('Qui de nous ? : vote pour soi refusé, votes anonymes, majorité +100, le plus désigné +50');
    tv.flush();
    gm(a, { t: 'game_end' });
    await live(tv, (g) => g.phase === 'podium');
    gm(a, { t: 'game_skip' });
    await tv.room((r) => r.phase === 'lobby');
    step('Qui de nous ? : arrêt par l’hôte, podium, retour au salon');
    for (const x of [tv, ...ps]) x.close();
  }

  // ================= Réponses drôles
  {
    const { tv, ps } = await setup(['Ana', 'Ben', 'Cléo']);
    const [a, b, c] = ps;
    a.send({ t: 'select_game', game: 'droles' });
    a.send({ t: 'start_game' });
    let g = (await live(tv, (g) => g.id === 'droles' && g.phase === 'write' && g.index === 0)).room.game;
    assert.ok(g.prompt.includes('___'));
    gm(a, { t: 'drl_answer', r: 0, text: '  un​ vieux   bonnet  ' });
    gm(a, { t: 'drl_answer', r: 0, text: 'une chaussette trouée' }); // correction permise
    gm(b, { t: 'drl_answer', r: 0, text: 'x'.repeat(200) });
    gm(c, { t: 'drl_answer', r: 0, text: 'un câlin de belle-mère' });
    g = (await live(tv, (g) => g.phase === 'vote' && g.index === 0)).room.game;
    assert.equal(g.answers.length, 3);
    assert.ok(g.answers.every((x) => !('author' in x)), 'auteurs cachés pendant le vote');
    assert.ok(g.answers.some((x) => x.text === 'une chaussette trouée'));
    assert.ok(g.answers.every((x) => [...x.text].length <= 60));
    const idx = (t) => g.answers.find((x) => x.text === t).i;
    const youA = (await a.room((r, y) => r.game?.phase === 'vote' && y && y.mine !== null)).you;
    gm(a, { t: 'drl_vote', r: 0, a: youA.mine }); // pour soi : refusé
    gm(a, { t: 'drl_vote', r: 0, a: idx('un câlin de belle-mère') });
    gm(b, { t: 'drl_vote', r: 0, a: idx('un câlin de belle-mère') });
    gm(c, { t: 'drl_vote', r: 0, a: idx('une chaussette trouée') });
    g = (await live(tv, (g) => g.phase === 'reveal' && g.index === 0)).room.game;
    const best = g.answers.find((x) => x.text === 'un câlin de belle-mère');
    assert.equal(best.author, c.pid); assert.equal(best.votes, 2); assert.ok(best.best);
    assert.equal(g.ranking.find((x) => x.pid === c.pid).gain, 2 * 100 + 200);
    assert.equal(g.ranking.find((x) => x.pid === a.pid).gain, 100);
    step('Réponses drôles : texte nettoyé et limité à 60, auteurs cachés, pas de vote pour soi, 100/vote + 200 meilleure');
    tv.flush();
    gm(a, { t: 'game_skip' }); // manche suivante
    await live(tv, (g) => g.phase === 'write' && g.index === 1);
    gm(a, { t: 'drl_answer', r: 1, text: 'seul' });
    gm(a, { t: 'game_skip' }); // fin de l'écriture : 1 seule réponse → pas de vote
    g = (await live(tv, (g) => g.phase === 'reveal' && g.index === 1)).room.game;
    step('Réponses drôles : avec une seule réponse, on saute le vote');
    for (const x of [tv, ...ps]) x.close();
  }

  // ================= Course de réflexes
  {
    const { tv, ps } = await setup(['Ana', 'Ben', 'Cléo']);
    const [a, b, c] = ps;
    a.send({ t: 'select_game', game: 'reflexes' });
    a.send({ t: 'game_option', key: 'trials', value: 12 });
    a.send({ t: 'start_game' });
    const seen = new Set();
    for (let k = 0; k < 12; k++) {
      let g = (await live(tv, (g) => g.id === 'reflexes' && g.index === k && g.phase === 'ready', 6000)).room.game;
      seen.add(g.type);
      if (g.type === 'feu') {
        await live(tv, (g) => g.index === k && g.phase === 'wait');
        gm(c, { t: 'rfx', k }); // faux départ
        await live(tv, (g) => g.index === k && g.phase === 'go', 3000);
        gm(a, { t: 'rfx', k, rt: 230 });
        gm(b, { t: 'rfx', k, rt: 5 }); // trop rapide : ramené à 80 ms… et donc 1er (garde-fou)
        g = (await live(tv, (g) => g.index === k && g.phase === 'result')).room.game;
        assert.deepEqual(g.falseStart, [c.pid]);
        assert.equal(g.order[0].pid, b.pid); assert.equal(g.order[0].rt, 80);
        assert.equal(g.order[1].pid, a.pid);
      } else if (g.type === 'taps') {
        await live(tv, (g) => g.index === k && g.phase === 'go');
        gm(a, { t: 'rfx', k, n: 5 }); gm(b, { t: 'rfx', k, n: 9999 }); gm(c, { t: 'rfx', k, n: 3 });
        await sleep(300);
        gm(a, { t: 'rfx', k, n: 12 });
        g = (await live(tv, (g) => g.index === k && g.phase === 'result', 3000)).room.game;
        assert.ok(g.order.find((o) => o.pid === b.pid).n < 9999, 'taps plafonnés');
        assert.ok(g.order.find((o) => o.pid === a.pid).n === 12);
      } else if (g.type === 'couleur') {
        g = (await live(tv, (g) => g.index === k && g.phase === 'go')).room.game;
        assert.notEqual(g.word, g.ink);
        gm(a, { t: 'rfx', k, c: g.ink, rt: 120 });
        gm(b, { t: 'rfx', k, c: g.word, rt: 90 }); // a touché le mot, pas l'encre
        gm(c, { t: 'rfx', k, c: g.ink, rt: 250 });
        g = (await live(tv, (g) => g.index === k && g.phase === 'result')).room.game;
        assert.deepEqual(g.order.map((o) => o.pid), [a.pid, c.pid]);
      } else if (g.type === 'compte') {
        g = (await live(tv, (g) => g.index === k && g.phase === 'show')).room.game;
        const n = g.cells.length;
        g = (await live(tv, (g) => g.index === k && g.phase === 'go')).room.game;
        assert.ok(g.options.includes(n) && g.options.length === 4 && !('answer' in g));
        gm(a, { t: 'rfx', k, c: n, rt: 260 });
        gm(b, { t: 'rfx', k, c: g.options.find((o) => o !== n), rt: 90 });
        gm(c, { t: 'rfx', k, c: n, rt: 150 });
        g = (await live(tv, (g) => g.index === k && g.phase === 'result')).room.game;
        assert.equal(g.answer, n);
        assert.deepEqual(g.order.map((o) => o.pid), [c.pid, a.pid]);
        assert.deepEqual(g.order.map((o) => o.pts), [500, 400]);
      } else if (g.type === 'cible') {
        assert.ok(!('targets' in g), 'cibles cachées avant le départ');
        g = (await live(tv, (g) => g.index === k && g.phase === 'go')).room.game;
        assert.equal(g.targets.length, 5);
        await sleep(500);
        gm(a, { t: 'rfx', k, rt: 600 });
        gm(b, { t: 'rfx', k, rt: 450 });
        gm(c, { t: 'rfx', k, rt: 100 }); // impossible pour 5 cibles : ramené à 400 ms
        g = (await live(tv, (g) => g.index === k && g.phase === 'result')).room.game;
        assert.deepEqual(g.order.map((o) => o.pid), [c.pid, b.pid, a.pid]);
        assert.equal(g.order[0].rt, 400);
      } else if (g.type === 'fleches') {
        g = (await live(tv, (g) => g.index === k && g.phase === 'go')).room.game;
        assert.equal(g.arrows.length, 6);
        await sleep(700);
        gm(a, { t: 'rfx', k, rt: 900, e: 0 });
        gm(b, { t: 'rfx', k, rt: 600, e: 5 }); // 5 erreurs = +5 s
        gm(c, { t: 'rfx', k, rt: 50, e: 0 });
        g = (await live(tv, (g) => g.index === k && g.phase === 'result')).room.game;
        assert.deepEqual(g.order.map((o) => o.pid), [c.pid, a.pid, b.pid]);
        assert.equal(g.order[2].e, 5);
        assert.ok(g.order[2].rt > 1000);
      } else if (g.type === 'intrus') {
        g = (await live(tv, (g) => g.index === k && g.phase === 'go')).room.game;
        assert.notEqual(g.base, g.odd);
        await sleep(400);
        gm(a, { t: 'rfx', k, c: g.pos, rt: 300 });
        gm(b, { t: 'rfx', k, c: (g.pos + 1) % g.size, rt: 100 }); // mauvaise case
        gm(c, { t: 'rfx', k, c: g.pos, rt: 200 });
        g = (await live(tv, (g) => g.index === k && g.phase === 'result')).room.game;
        assert.deepEqual(g.order.map((o) => o.pid), [c.pid, a.pid]);
      } else if (g.type === 'chrono') {
        assert.ok(g.target >= 3000);
        await live(tv, (g) => g.index === k && g.phase === 'go');
        gm(a, { t: 'rfx', k, rt: 200 });
        gm(b, { t: 'rfx', k, rt: 100 });
        gm(c, { t: 'rfx', k, rt: 99999 }); // borné à ce que le serveur a vu (+ 300 ms)
        g = (await live(tv, (g) => g.index === k && g.phase === 'result')).room.game;
        assert.deepEqual(g.order.map((o) => o.pid), [c.pid, a.pid, b.pid]);
        assert.ok(g.order[0].stopped < 1500);
        assert.equal(g.order[1].rt, g.target - 200);
      }
    }
    assert.equal(seen.size, 8, 'les 8 épreuves');
    await live(tv, (g) => g.phase === 'podium', 4000);
    step('Course de réflexes : feu vert (faux départ, temps bornés), taps plafonnés, couleur de l’encre, compte des emojis, cibles, flèches (pénalités), intrus, chrono à l’aveugle, 8 épreuves différentes');
    for (const x of [tv, ...ps]) x.close();
  }

  // ================= Dessin à deviner
  {
    const { tv, ps } = await setup(['Ana', 'Ben', 'Cléo']);
    const byPid = Object.fromEntries(ps.map((p) => [p.pid, p]));
    ps[0].send({ t: 'select_game', game: 'dessin' });
    ps[0].send({ t: 'start_game' });
    let r = (await live(tv, (g) => g.id === 'dessin' && g.phase === 'choose' && g.turn === 0)).room;
    const drawer = byPid[r.game.drawer];
    const others = ps.filter((p) => p !== drawer);
    const youD = (await drawer.room((r, y) => r.game?.phase === 'choose' && y?.choices)).you;
    assert.equal(youD.choices.length, 3);
    const youO = (await others[0].room((r, y) => r.game?.phase === 'choose' && y)).you;
    assert.equal(youO.choices, null, 'les autres ne voient pas les mots');
    gm(drawer, { t: 'dsn_choose', i: 1 });
    const word = youD.choices[1];
    let g = (await live(tv, (g) => g.phase === 'draw')).room.game;
    assert.ok(!('word' in g) && /_/.test(g.mask) && [...g.mask].length === [...word].length);
    // traits : la TV et l'autre joueur les reçoivent, pas le dessinateur
    gm(drawer, { t: 'drw_stroke', s: 1, c: 3, w: 12, p: [10, 10, 500, 500, 2000, -5] });
    const op = await tv.wait((m) => m.t === 'draw' && m.op === 'pts');
    assert.deepEqual(op.p, [10, 10, 500, 500, 1000, 0]);
    await others[1].wait((m) => m.t === 'draw' && m.op === 'pts');
    gm(others[0], { t: 'drw_stroke', s: 2, c: 1, w: 5, p: [1, 1, 2, 2] }); // pas le dessinateur : ignoré
    tv.send({ t: 'tv_game_msg', m: { t: 'drw_sync' } });
    const full = await tv.wait((m) => m.t === 'draw' && m.op === 'full');
    assert.equal(full.strokes.length, 1);
    step('Dessin : 3 mots pour le dessinateur seulement, mot masqué, traits relayés et bornés, resynchro TV');
    // propositions
    const w = word.normalize('NFKD').replace(/\p{M}/gu, '');
    const close = w.length >= 4 ? w.slice(0, -1) + (w.at(-1) === 'x' ? 'y' : 'x') : null;
    if (close) {
      gm(others[0], { t: 'dsn_guess', text: close });
      await others[0].wait('dsn_close');
    }
    gm(others[0], { t: 'dsn_guess', text: 'zzzz' });
    g = (await live(tv, (g) => g.feed?.some((f) => f.text === 'zzzz'))).room.game;
    assert.ok(!g.feed.some((f) => f.text === close), 'une proposition « chaude » ne s’affiche pas');
    gm(others[0], { t: 'dsn_guess', text: ` ${w.toUpperCase()} ` });
    await others[0].wait('dsn_found');
    gm(others[1], { t: 'dsn_guess', text: word });
    g = (await live(tv, (g) => g.phase === 'reveal' && g.turn === 0)).room.game;
    assert.equal(g.word, word);
    const gain = (p) => g.ranking.find((x) => x.pid === p.pid).gain;
    assert.ok(gain(others[0]) > gain(others[1]), 'le premier qui trouve gagne plus');
    assert.equal(gain(drawer), 200);
    step('Dessin : « chaud » en privé, accents et majuscules ignorés, tout le monde a trouvé → révélation, points');
    // le dessinateur part pendant son tour
    r = (await live(tv, (g) => g.phase === 'choose' && g.turn === 1, 3000)).room;
    const d2 = byPid[r.game.drawer];
    gm(d2, { t: 'dsn_choose', i: 0 });
    await live(tv, (g) => g.phase === 'draw' && g.turn === 1);
    d2.close();
    await live(tv, (g) => g.phase === 'reveal' && g.turn === 1, 3000);
    step('Dessin : le dessinateur part → fin du tour sans bloquer');
    for (const x of [tv, ...ps]) x.close();
  }

  // ================= Touche Retour de l'appli TV : arrêter la partie
  {
    const { tv, ps } = await setup(['Ana', 'Ben']);
    ps[0].send({ t: 'select_game', game: 'reflexes' });
    ps[0].send({ t: 'start_game' });
    await live(tv, (g) => g.id === 'reflexes');
    ps[1].send({ t: 'tv_game_msg', m: { t: 'tv_stop' } }); // un téléphone ne peut pas
    await sleep(300);
    tv.flush();
    tv.send({ t: 'tv_game_msg', m: { t: 'tv_stop' } });
    await tv.room((r) => r.phase === 'lobby' && r.game === null);
    step('Appli TV : la touche Retour arrête la partie (la TV seulement)');
    for (const x of [tv, ...ps]) x.close();
  }

  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exitCode = 1;
} finally {
  srv.kill('SIGTERM');
}
