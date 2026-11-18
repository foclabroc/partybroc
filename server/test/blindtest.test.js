// Blind test : titres nettoyés, mauvaises réponses, partie complète avec un faux Deezer (sans réseau ni base).
//   PB_FAST=1 node test/blindtest.test.js
process.env.PB_FAST = '1';
const assert = (await import('node:assert/strict')).default;
const { setDeezerFetch, cleanTitle, cleanAlbum } = await import('../src/deezer.js');
const { BlindTestGame, distractors, BT } = await import('../src/games/blindtest.js');
const { gameById } = await import('../src/games/index.js');

let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const until = async (f, ms = 4000) => { const t = Date.now(); while (!f()) { if (Date.now() - t > ms) throw new Error('délai dépassé'); await sleep(10); } };

// Faux Deezer : 24 musiques (dont une explicite), /track/<id> donne une adresse fraîche
let previews = true;
const track = (i, extra = {}) => ({
  id: 1000 + i, readable: true, title: `Chanson ${i} (feat. Quelqu'un)`, title_short: `Chanson ${i}`,
  preview: `https://cdn/old/${i}.mp3`, explicit_lyrics: false,
  artist: { name: `Artiste ${i % 12}` }, album: { title: `Album ${i}`, cover_big: `https://img/${i}.jpg` }, ...extra,
});
setDeezerFetch(async (path) => {
  if (path.startsWith('/playlist/')) return { data: [...Array.from({ length: 24 }, (_, i) => track(i)), track(99, { explicit_lyrics: true })] };
  if (path.startsWith('/chart')) return { data: [] };
  const m = path.match(/^\/track\/(\d+)/);
  if (m) return previews ? { id: +m[1], readable: true, preview: `https://cdn/fresh/${m[1]}.mp3` } : { id: +m[1], readable: false, preview: '' };
  throw new Error('chemin inconnu ' + path);
});

function room(n) {
  const players = new Map();
  for (let i = 0; i < n; i++) players.set('p' + i, { pid: 'p' + i, connected: true, name: 'J' + i });
  return { players, hostPid: 'p0', used: {} };
}

try {
  {
    assert.equal(cleanTitle('Chocolat (feat. Awa Imani)'), 'Chocolat');
    assert.equal(cleanTitle('Creep - Remastered 2009'), 'Creep');
    assert.equal(cleanTitle('She-Ra Princess of Power (1985) - Theme Song'), 'She-Ra Princess of Power');
    assert.equal(cleanTitle('(I Just) Died In Your Arms'), '(I Just) Died In Your Arms');
    assert.equal(cleanAlbum('Vaiana - La Légende du Bout du Monde (Bande originale française du Film)'), 'Vaiana');
    assert.equal(cleanAlbum('The Lion King: Special Edition Original Soundtrack (French Version)'), 'The Lion King');
    const pool = [
      { artist: 'Queen', group: 'g', kind: 'artist' }, { artist: 'Queen & David Bowie', group: 'g', kind: 'artist' },
      { artist: 'QUEEN', group: 'g', kind: 'artist' }, { artist: 'Abba', group: 'g', kind: 'artist' },
      { artist: 'Blur', group: 'g', kind: 'artist' }, { artist: 'Oasis', group: 'h', kind: 'artist' },
    ];
    const d = distractors(pool[0], pool, 'artist');
    assert.equal(d.length, 3);
    assert.ok(!d.some((x) => /queen/i.test(x)), 'ni la bonne réponse ni un nom trop proche');
    step('titres et films nettoyés, 3 mauvaises réponses différentes de la bonne');
  }
  {
    assert.ok(gameById('blindtest')?.ready, 'au catalogue');
    const r = room(2);
    const g = await BlindTestGame.create(r, { playlist: 'Années 80', rounds: 10 }, { changed() {}, finished() {} });
    assert.equal(g.pool.length, 24, 'la musique explicite est écartée');
    assert.equal(g.count, 10);
    let finished = null;
    g.hooks = { changed() {}, finished(res) { finished = res; } };
    g.start();
    await until(() => g.phase === 'load' && g.round);
    const load = g.publicState();
    assert.match(load.audio, /fresh/, 'adresse de l’extrait redemandée à Deezer');
    assert.equal(load.artists, undefined, 'pas de choix pendant le chargement');
    await until(() => g.phase === 'ask');
    const ask = g.publicState();
    assert.equal(ask.artists.length, 4);
    assert.equal(ask.titles.length, 4);
    for (const k of ['ca', 'ct', 'artist', 'title', 'cover', 'picks']) assert.equal(ask[k], undefined, `${k} caché pendant l’écoute`);
    const { ca, ct } = g.round;
    g.onMessage({ pid: 'p0' }, { t: 'bt_pick', r: 0, k: 'a', choice: ca });
    g.onMessage({ pid: 'p0' }, { t: 'bt_pick', r: 0, k: 'a', choice: (ca + 1) % 4 });
    assert.equal(g.answers.get('p0').a.v, ca, 'un seul essai par colonne');
    assert.deepEqual(g.publicState().answered, { p0: 'a' });
    g.onMessage({ pid: 'p0' }, { t: 'bt_pick', r: 0, k: 't', choice: ct });
    g.onMessage({ pid: 'p1' }, { t: 'bt_pick', r: 0, k: 'a', choice: (ca + 1) % 4 });
    g.onMessage({ pid: 'p1' }, { t: 'bt_pick', r: 0, k: 't', choice: ct });
    g.onMessage({ pid: 'p1' }, { t: 'bt_pick', r: 5, k: 't', choice: 9 });
    await until(() => g.phase === 'reveal');
    const rv = g.publicState();
    assert.equal(rv.ca, ca);
    assert.ok(rv.cover && rv.title && rv.artist);
    const s0 = g.scores.get('p0'), s1 = g.scores.get('p1');
    assert.ok(s0 >= 2 * BT.basePoints + BT.bothBonus, `p0 a les deux + bonus (${s0})`);
    assert.ok(s1 >= BT.basePoints && s1 <= BT.basePoints + BT.speedPoints, `p1 seulement le titre (${s1})`);
    assert.equal(g.playerState('p0').found.a, 1);
    step('écoute → révélation : réponses cachées, un essai par colonne, points + bonus des deux');
    // Le reste de la partie tout seul (personne ne répond) jusqu'au podium
    await until(() => finished, 60000);
    assert.equal(g.index, 9);
    assert.equal(g.publicState().played, 10);
    assert.equal(r.used.blindtest.size, 10, 'musiques notées pour ne pas les rejouer ce soir');
    step('10 extraits joués jusqu’au podium, musiques de la soirée retenues');
  }
  {
    previews = false;
    const g = await BlindTestGame.create(room(1), { playlist: 'Mélange', rounds: 10 }, { changed() {}, finished() {} });
    g.start();
    await until(() => g.phase === 'podium', 8000).catch((e) => { console.log('état', g.phase, g.index, g.next_, g.loading, g.picks.length); throw e; });
    assert.equal(g.count, 0);
    g.stop();
    setDeezerFetch(async () => { throw new Error('hors ligne'); });
    await assert.rejects(BlindTestGame.create(room(1), {}, { changed() {}, finished() {} }), /Deezer ne répond pas/);
    step('Deezer sans extrait ou hors ligne : podium direct, ou message clair au lancement');
  }
  console.log(`Blind test : ${ok} étapes OK`);
  process.exit(0);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exit(1);
}
