// Quiz cinéma : faux titres, partie complète avec un faux TMDB (sans réseau ni base), indice.
//   PB_FAST=1 node test/cine.test.js
process.env.PB_FAST = '1';
const assert = (await import('node:assert/strict')).default;
const { setTmdbFetch } = await import('../src/tmdb.js');
const { CineGame, wrongTitles, CINE } = await import('../src/games/cine.js');
const { gameById } = await import('../src/games/index.js');

let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const until = async (f, ms = 5000) => { const t = Date.now(); while (!f()) { if (Date.now() - t > ms) throw new Error('délai dépassé'); await sleep(10); } };

let calls = 0;
setTmdbFetch(async (p, params) => {
  calls++;
  if (p === '/genre/movie/list') return { genres: [{ id: 16, name: 'Animation' }, { id: 35, name: 'Comédie' }] };
  if (p === '/discover/movie') {
    const page = params.page;
    return { results: Array.from({ length: 20 }, (_, i) => ({ id: page * 100 + i, title: `Film ${page}-${i}`, release_date: `${1980 + i}-05-01`, genre_ids: [16, 35], backdrop_path: `/b${page}${i}.jpg`, poster_path: `/p${i}.jpg` })) };
  }
  if (/^\/movie\/\d+\/images$/.test(p)) return { backdrops: [{ file_path: '/scene.jpg', width: 1920, vote_count: 3 }] };
  if (/^\/movie\/\d+\/credits$/.test(p)) return { crew: [{ job: 'Director', name: 'Jeanne Exemple' }] };
  throw new Error('chemin inconnu ' + p);
});

function room(n) {
  const players = new Map();
  for (let i = 0; i < n; i++) players.set('p' + i, { pid: 'p' + i, connected: true, name: 'J' + i });
  return { players, hostPid: 'p0', used: {} };
}

try {
  {
    const pool = [
      { id: 1, title: 'Shrek', year: 2001, group: 'g' }, { id: 2, title: 'Shrek 2', year: 2004, group: 'g' },
      { id: 3, title: 'Cars', year: 2006, group: 'g' }, { id: 4, title: 'Coco', year: 2017, group: 'g' },
      { id: 5, title: 'Là-haut', year: 2009, group: 'g' }, { id: 6, title: 'Rio', year: 2011, group: 'h' },
    ];
    const w = wrongTitles(pool[0], pool);
    assert.equal(w.length, 3);
    assert.ok(!w.includes('Shrek') && !w.includes('Shrek 2'), 'ni le bon titre ni une suite');
    assert.ok(gameById('cine')?.ready, 'au catalogue');
    step('3 faux titres sans le bon film ni ses suites, jeu au catalogue');
  }
  {
    const g = await CineGame.create(room(2), { categorie: 'Dessins animés', rounds: 10, temps: '30 s', indice: 'Avec' }, { changed() {}, finished() {} });
    let finished = null;
    g.hooks = { changed() {}, finished(r) { finished = r; } };
    g.start();
    await until(() => g.phase === 'ask');
    const ask = g.publicState();
    assert.match(ask.image, /image\.tmdb\.org\/t\/p\/w1280\/scene\.jpg$/);
    assert.equal(ask.choices.length, 4);
    for (const k of ['correct', 'title', 'year', 'director', 'poster', 'picks', 'hint']) assert.equal(ask[k], undefined, `${k} caché pendant la question`);
    const c = g.round.correct;
    g.onMessage({ pid: 'p0' }, { t: 'cine_pick', r: 0, choice: c });
    g.onMessage({ pid: 'p0' }, { t: 'cine_pick', r: 0, choice: (c + 1) % 4 });
    assert.equal(g.answers.get('p0').v, c, 'un seul essai');
    // l'indice arrive à 10 s de la fin (÷10 ici)
    await until(() => g.publicState().hint, 4000);
    assert.match(g.publicState().hint, /^\d{4} · Animation · Comédie$/);
    g.onMessage({ pid: 'p1' }, { t: 'cine_pick', r: 0, choice: c });
    await until(() => g.phase === 'reveal');
    const rv = g.publicState();
    assert.equal(rv.correct, c);
    assert.equal(rv.director, 'Jeanne Exemple');
    assert.ok(g.scores.get('p0') > CINE.basePoints, 'avant l’indice : 500 + rapidité');
    assert.equal(g.scores.get('p1'), CINE.hintPoints, 'après l’indice : moins de points');
    step('question → indice → révélation : choix sans réponse, un essai, points réduits après l’indice');
    await until(() => finished, 60000);
    assert.equal(g.index, 9);
    step('10 images jusqu’au podium');
  }
  {
    const before = calls;
    await CineGame.create(room(1), { categorie: 'Dessins animés' }, { changed() {}, finished() {} });
    assert.equal(calls, before, 'liste des films gardée en mémoire');
    setTmdbFetch(async () => { throw new Error('Clé TMDB refusée'); });
    await assert.rejects(CineGame.create(room(1), { categorie: 'Années 80' }, { changed() {}, finished() {} }), /Clé TMDB refusée/);
    step('films gardés en mémoire ; clé refusée = message clair au lancement');
  }
  console.log(`Quiz cinéma : ${ok} étapes OK`);
  process.exit(0);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exit(1);
}
