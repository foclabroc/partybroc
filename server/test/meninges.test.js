// Bataille de méninges (sans base, en mémoire) : 60 épreuves, questions fabriquées et vérifiées,
// chacun à son rythme, réponses jamais envoyées avant coup, robots, podium.
//   PB_FAST=1 node test/meninges.test.js
process.env.PB_FAST = '1';
const assert = (await import('node:assert/strict')).default;
const { Room } = await import('../src/rooms.js');
const { EPREUVES, CATS, makeQuestion, checkAnswer, MNG } = await import('../src/games/meninges.js');

let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const until = async (f, ms = 8000) => { const t = Date.now(); while (!f()) { if (Date.now() - t > ms) throw new Error('délai dépassé'); await sleep(5); } };

// La bonne réponse dans la forme qu'enverrait un téléphone
function goodAnswer(q) {
  if (q.k === 'seq' && q.word) {
    const used = new Set(); const out = []; let pos = 0;
    while (pos < q.word.length) { const k = q.items.findIndex((it, j) => !used.has(j) && q.word.startsWith(it.t, pos)); used.add(k); out.push(k); pos += q.items[k].t.length; }
    return out;
  }
  return q.ans;
}

try {
  {
    assert.equal(EPREUVES.length, 60);
    for (const c of CATS) assert.ok(EPREUVES.filter((e) => e.cat === c.id).length >= 8, c.id);
    // Toutes les épreuves, à tous les niveaux : la question se fabrique, la bonne réponse passe, une mauvaise non
    for (const e of EPREUVES) for (let L = 1; L <= 5; L++) for (let i = 0; i < 25; i++) {
      const q = makeQuestion(e, `s${i}`, i, L);
      assert.ok(checkAnswer(q, goodAnswer(q)), `${e.id} niveau ${L} : bonne réponse refusée`);
      assert.ok(!checkAnswer(q, q.k === 'num' ? q.ans + 1 : q.k === 'pick' || q.k === 'cups' ? -1 : [999]), `${e.id} : mauvaise réponse acceptée`);
    }
    // Même graine = même question (tout le monde a les mêmes questions dans le même ordre)
    const e = EPREUVES.find((x) => x.id === 'intrus');
    assert.deepEqual(makeQuestion(e, 'abc', 3, 2), makeQuestion(e, 'abc', 3, 2));
    // Mot mélangé : une autre vraie anagramme compte aussi
    const q = { k: 'seq', n: 5, word: 'CHIEN', items: 'NICHE'.split('').map((t) => ({ t })) };
    assert.ok(checkAnswer(q, [0, 1, 2, 3, 4]));
    step('60 épreuves (8 ou 9 par catégorie), 1500 questions vérifiées, mêmes questions pour tous');
  }

  {
    const room = new Room('MENG');
    const sent = { a: [], b: [] };
    const a = room.addPlayer({ name: 'Ana', emoji: '🙂', color: 0, photo: null });
    const b = room.addPlayer({ name: 'Bob', emoji: '🙂', color: 1, photo: null });
    a.ws = { readyState: 1, send: (s) => sent.a.push(JSON.parse(s)) };
    b.ws = { readyState: 1, send: (s) => sent.b.push(JSON.parse(s)) };
    room.selectedGame = 'meninges';
    room.options.meninges.rounds = 5;
    let results = null;
    const end = room.endGame.bind(room);
    room.endGame = (r) => { results = r; end(r); };
    await room.startGame();
    const g = room.game;
    assert.equal(g.plan.length, 5);
    assert.equal(new Set(g.plan.map((x) => x.cat)).size, 5, 'une catégorie différente à chaque manche');
    await until(() => g.phase === 'go');
    const lastQ = (list) => [...list].reverse().find((m) => m.t === 'mng_q');
    await until(() => lastQ(sent.a) && lastQ(sent.b));
    // La question envoyée ne contient pas la réponse
    for (const m of [...sent.a, ...sent.b]) {
      if (m.t === 'mng_q') assert.equal(m.q.ans, undefined);
      if (m.t === 'room') assert.ok(!JSON.stringify(m.room.game).includes('"ans"'));
    }
    // Ana répond juste 4 fois de suite : elle avance, son cerveau grossit ; Bob se trompe et est bloqué
    for (let k = 0; k < 4; k++) {
      const s = g.st.get(a.pid);
      g.onMessage(a, { t: 'mng_answer', r: g.index, i: s.q.i, v: goodAnswer(s.q) });
    }
    const sa = g.st.get(a.pid);
    assert.equal(sa.ok, 4);
    assert.equal(sa.done, 4);
    assert.ok(sa.total > 0);
    assert.equal(sa.level, 3, 'niveau +1 après 3 bonnes réponses d’affilée');
    const sb = g.st.get(b.pid);
    const bi = sb.q.i;
    g.onMessage(b, { t: 'mng_answer', r: g.index, i: bi, v: sb.q.k === 'num' ? -1 : sb.q.k === 'pick' || sb.q.k === 'cups' ? -1 : [] });
    assert.equal(sb.ko, 1);
    assert.equal(sb.level, 1);
    const qb = lastQ(sent.b);
    assert.equal(qb.last.ok, false);
    assert.equal(qb.wait, MNG.wrongMs);
    // Bloqué : une réponse tout de suite ne compte pas
    g.onMessage(b, { t: 'mng_answer', r: g.index, i: sb.q.i, v: goodAnswer(sb.q) });
    assert.equal(sb.ok, 0);
    // Réponse à une vieille question : ignorée
    g.onMessage(a, { t: 'mng_answer', r: g.index, i: 0, v: 0 });
    assert.equal(sa.done, 4);
    await until(() => g.phase === 'result');
    const pub = g.publicState();
    assert.equal(pub.players[a.pid].ok, 4);
    assert.ok(pub.players[a.pid].w > MNG.baseGrams);
    step('chacun à son rythme : question suivante tout de suite, niveau qui monte, erreur = 1 s bloqué');

    // L'animateur a annoncé quelque chose, la manche est gagnée par Ana
    assert.ok(pub.news && /Ana/.test(pub.news.text), `annonce : ${pub.news?.text}`);
    g.onMessage(a, { t: 'game_end' });
    await until(() => results);
    const ra = results.find((r) => r.pid === a.pid);
    assert.equal(ra.rank, 1);
    assert.equal(ra.score, 1000);
    assert.ok(ra.grams > 0);
    assert.equal(results.find((r) => r.pid === b.pid).score, 0);
    step('annonces de l’animateur, podium : 1000 points au cerveau le plus lourd, grammes gardés');
  }

  {
    // Robots seuls jusqu'au podium
    const room = new Room('MENB');
    room.addBot('malin'); room.addBot('facile');
    room.selectedGame = 'meninges';
    room.options.meninges.rounds = 5;
    room.options.meninges.without = 'Mots et Réflexe';
    let results = null;
    const end = room.endGame.bind(room);
    room.endGame = (r) => { results = r; end(r); };
    await room.startGame();
    assert.ok(room.game.plan.every((e) => e.cat !== 'mot' && e.cat !== 'rfx'));
    await until(() => results, 60000);
    room.clearBots();
    assert.equal(results.length, 2);
    assert.ok(results.some((r) => r.grams > 0), 'les robots ont marqué');
    step('robots seuls jusqu’au podium, option « Sans Mots et Réflexe »');
  }

  console.log(`\nBataille de méninges : ${ok} étapes OK`);
  process.exit(0);
} catch (e) {
  console.error('\n✗ ÉCHEC :', e);
  process.exit(1);
}
