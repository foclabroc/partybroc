// Les 7 jeux de la 0.8 + salon de 15 joueurs.   PB_DB_URL=postgresql://… PB_FAST=1 node test/jeux2.test.js
import assert from 'node:assert/strict';
import { startServer, client } from './lib.js';

const PORT = 4194;
const srv = await startServer(PORT, { PB_FAST: '1', PB_ROOMS_PER_IP: '100' });
let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const DB = !!process.env.PB_DB_URL;

// Un salon : TV + n joueurs (le premier est l'hôte)
async function salon(names) {
  const tv = await client(PORT);
  tv.send({ t: 'tv_hello' });
  const { code } = await tv.wait('tv_ok');
  const ps = [];
  for (const name of names) {
    const c = await client(PORT);
    c.send({ t: 'join', code, name, emoji: '🙂', color: 0, photo: '' });
    c.me = (await c.wait('joined')).pid;
    ps.push(c);
  }
  return { tv, code, ps, host: ps[0] };
}
const R = async (c, cond, ms = 6000) => (await c.room(cond, ms));
const g = (m) => ({ t: 'game_msg', m });
async function launch(s, game, opts = {}) {
  s.host.send({ t: 'select_game', game });
  for (const [key, value] of Object.entries(opts)) s.host.send({ t: 'game_option', key, value });
  await sleep(100);
  s.host.send({ t: 'start_game' });
  const e = await s.host.wait('error', 400).catch(() => null);
  if (e) throw new Error(`${game} : ${e.msg}`);
}
const close = (s) => { s.tv.close(); for (const p of s.ps) p.close(); };

// Résultat d'un calcul affiché (×, ÷, −, ², « % de »)
function solve(text) {
  const pct = text.match(/^(\d+) % de (\d+)$/);
  if (pct) return (Number(pct[1]) * Number(pct[2])) / 100;
  const js = text.replace(/×/g, '*').replace(/÷/g, '/').replace(/−/g, '-').replace(/(\d+)²/g, '($1*$1)');
  return Function(`return (${js})`)();
}

try {
  // ---- 15 joueurs ----
  {
    const names = Array.from({ length: 15 }, (_, i) => `Joueur${i + 1}`);
    const s = await salon(names);
    const r = await R(s.tv, (r) => r.players.length === 15);
    assert.equal(r.room.maxPlayers, 15);
    const extra = await client(PORT);
    extra.send({ t: 'join', code: s.code, name: 'Seize', emoji: '🙂', color: 0, photo: '' });
    assert.match((await extra.wait('error')).msg, /15 joueurs max/);
    close(s); extra.close();
    step('Salon : 15 joueurs, le 16e est refusé');
  }

  // ---- Course de calcul ----
  {
    const s = await salon(['Alice', 'Bob']);
    const [a, b] = s.ps;
    await launch(s, 'calcul', { level: 'Difficile', rounds: 10 });
    const q = (await R(s.tv, (r) => r.game?.phase === 'ask')).room.game;
    assert.ok(q.expr && q.value === undefined, 'pas de résultat avant la révélation');
    const v = solve(q.expr);
    assert.ok(Number.isInteger(v), `résultat entier : ${q.expr} = ${v}`);
    a.send(g({ t: 'calc_answer', r: q.index, v }));
    await sleep(50);
    b.send(g({ t: 'calc_answer', r: q.index, v: v + 1 }));
    const rev = (await R(s.tv, (r) => r.game?.phase === 'reveal')).room.game;
    assert.equal(rev.value, v);
    assert.equal(rev.first, a.me);
    const ga = rev.ranking.find((x) => x.pid === a.me).gain;
    assert.ok(ga >= 400 && ga <= 1100, `points ${ga}`);
    assert.equal(rev.ranking.find((x) => x.pid === b.me).gain, 0);
    // calculs de tous les niveaux : toujours entiers
    const { makeCalc } = await import('../src/games/calcul.js');
    for (const lvl of ['Facile', 'Moyen', 'Difficile']) for (let i = 0; i < 300; i++) {
      const c = makeCalc(lvl, i / 299);
      assert.ok(Number.isInteger(c.value) && c.value >= 0 && solve(c.text) === c.value, `${lvl} : ${c.text} = ${c.value}`);
    }
    close(s);
    step('Course de calcul : résultat caché, bon + premier = points, faux = 0 ; 900 calculs vérifiés (entiers, positifs)');
  }

  // ---- Mémoire ----
  {
    const s = await salon(['Alice', 'Bob']);
    const [a, b] = s.ps;
    await launch(s, 'memoire');
    const show = (await R(s.tv, (r) => r.game?.phase === 'show')).room.game;
    assert.equal(show.cells.length, 12);
    assert.equal(show.question, undefined, 'pas de question pendant qu’on regarde');
    const ask = (await R(s.tv, (r) => r.game?.phase === 'ask')).room.game;
    assert.equal(ask.cells, undefined, 'la grille est cachée pendant la question');
    assert.ok(ask.question && ask.choices.length === 4 && ask.correct === undefined);
    a.send(g({ t: 'mem_pick', r: ask.index, choice: 0 }));
    b.send(g({ t: 'mem_pick', r: ask.index, choice: 1 }));
    const rev = (await R(s.tv, (r) => r.game?.phase === 'reveal')).room.game;
    assert.equal(rev.cells.length, 12);
    for (const [p, c] of [[a, 0], [b, 1]]) assert.equal(rev.ranking.find((x) => x.pid === p.me).gain > 0, c === rev.correct);
    // la bonne réponse correspond bien à la grille
    const { makeScene, makeQuestion } = await import('../src/games/memoire.js');
    for (let i = 0; i < 400; i++) {
      const cells = makeScene();
      const q = makeQuestion(cells);
      assert.equal(new Set(q.choices).size, 4, q.text);
      const good = q.choices[q.correct];
      const m = q.text.match(/^Combien y avait-il de (.+) \?$/);
      if (m) assert.equal(cells.filter((x) => x.e === m[1]).length, Number(good));
      if (q.text.startsWith('Lequel')) assert.ok(!cells.some((x) => x.e === good));
      const c = q.text.match(/^De quelle couleur était la case de (.+) \?$/);
      if (c) assert.equal(cells.find((x) => x.e === c[1]).c, good);
    }
    close(s);
    step('Mémoire : grille montrée puis cachée pendant la question, points ; 400 questions vérifiées sur leur grille');
  }

  // ---- Zoom mystère ----
  {
    const s = await salon(['Alice', 'Bob']);
    const [a, b] = s.ps;
    await launch(s, 'zoom', { rounds: 6 });
    const ask = (await R(s.tv, (r) => r.game?.phase === 'ask')).room.game;
    assert.ok(ask.e && ask.choices.length === 4 && ask.correct === undefined);
    a.send(g({ t: 'zoom_pick', r: ask.index, choice: 2 }));
    a.send(g({ t: 'zoom_pick', r: ask.index, choice: 3 })); // un seul essai
    b.send(g({ t: 'zoom_pick', r: ask.index, choice: 3 }));
    const rev = (await R(s.tv, (r) => r.game?.phase === 'reveal')).room.game;
    assert.equal(rev.picks[a.me], 2);
    for (const [p, c] of [[a, 2], [b, 3]]) assert.equal(rev.ranking.find((x) => x.pid === p.me).gain > 0, c === rev.correct);
    close(s);
    step('Zoom mystère : nom caché, un seul essai, points si trouvé');
  }

  // ---- Petit bac ----
  {
    const s = await salon(['Alice', 'Bob']);
    const [a, b] = s.ps;
    await launch(s, 'petitbac', { rounds: 3 });
    const w = (await R(s.tv, (r) => r.game?.phase === 'write')).room.game;
    const L = w.letter;
    assert.equal(w.categories.length, 5);
    assert.equal(w.sheets, undefined);
    const mk = (k) => w.categories.map((_, c) => `${L}${'abcde'[c]}${k}`);
    // Bob écrit (sauvegarde), Alice remplit tout et crie « Stop ! »
    b.send(g({ t: 'bac_write', r: w.index, answers: [mk('x')[0], `${L}aa`, '', 'Zut', mk('x')[4]] }));
    a.send(g({ t: 'bac_write', r: w.index, answers: mk('y').map((t, c) => (c === 1 ? `${L}AA` : t)), done: true }));
    const st = (await R(s.tv, (r) => r.game?.stopBy === a.me)).room.game;
    assert.ok(st.endsIn <= 1100, 'Stop ! raccourcit le temps');
    const chk = (await R(s.tv, (r) => r.game?.phase === 'check')).room.game;
    assert.equal(chk.sheets[b.me][3].ok, false, 'Zut ne commence pas par la lettre');
    // Bob refuse la réponse d'Alice en catégorie 4
    b.send(g({ t: 'bac_veto', r: chk.index, pid: a.me, c: 4, on: true }));
    a.send(g({ t: 'bac_ok', r: chk.index }));
    b.send(g({ t: 'bac_ok', r: chk.index }));
    const rev = (await R(s.tv, (r) => r.game?.phase === 'reveal')).room.game;
    const row = (c, p) => rev.table[c].rows.find((x) => x.pid === p.me);
    assert.equal(row(0, a).pts, 100);            // réponses différentes : 100 chacun
    assert.equal(row(1, a).pts, 50);             // même mot (accents/majuscules ignorés) : 50
    assert.equal(row(1, b).pts, 50);
    assert.equal(row(2, a).pts, 150);            // seul à avoir répondu : 150
    assert.equal(row(3, b).pts, 0);              // ne commence pas par la lettre
    assert.equal(row(4, a).refused, true);       // refusée par la majorité des autres
    assert.equal(row(4, b).pts, 150);
    close(s);
    step('Petit bac : réponses cachées pendant l’écriture, « Stop ! », lettre vérifiée, refus à la majorité, 150/100/50');
  }

  if (DB) {
    // ---- Le juste prix ----
    {
      const s = await salon(['Alice', 'Bob', 'Carla']);
      const [a, b, c] = s.ps;
      await launch(s, 'justeprix', { rounds: 5 });
      const ask = (await R(s.tv, (r) => r.game?.phase === 'ask')).room.game;
      assert.ok(ask.name && ask.price === undefined, 'pas de prix avant la révélation');
      a.send(g({ t: 'jp_guess', r: ask.index, v: 0.5 }));
      b.send(g({ t: 'jp_guess', r: ask.index, v: '99999,99' }));
      c.send(g({ t: 'jp_guess', r: ask.index, v: 'abc' })); // refusé
      c.send(g({ t: 'jp_guess', r: ask.index, v: 2 }));
      const rev = (await R(s.tv, (r) => r.game?.phase === 'reveal')).room.game;
      assert.ok(rev.price > 0);
      const by = Object.fromEntries(rev.guesses.map((x) => [x.pid, x]));
      assert.equal(by[b.me].v, 99999.99);
      const d = (v) => Math.abs(v - rev.price);
      const best = [a, b, c].sort((x, y) => d(by[x.me].v) - d(by[y.me].v))[0];
      assert.equal(by[best.me].rank, 0);
      assert.ok(rev.ranking.find((x) => x.pid === best.me).gain >= 500);
      close(s);
      step('Juste prix : prix caché, saisie « 99999,99 » acceptée, le plus proche marque 500+');
    }

    // ---- Qui a dit ça ? ----
    {
      const s = await salon(['Alice', 'Bob', 'Carla']);
      const [a, b, c] = s.ps;
      await launch(s, 'quiadit', { rounds: 6 });
      await R(s.tv, (r) => r.game?.phase === 'intro');
      s.host.send(g({ t: 'game_skip' })); // l'hôte passe l'intro : on doit arriver à l'écriture
      await R(s.tv, (r) => r.game?.phase === 'write');
      for (const p of s.ps) {
        const m = await p.wait((m) => m.t === 'room' && m.you?.prompts?.length === 2, 4000);
        assert.ok(m.you.prompts.every((x) => typeof x === 'string'));
        p.send(g({ t: 'qad_write', i: 0, text: `réponse 1 de ${p.me}` }));
        p.send(g({ t: 'qad_write', i: 1, text: `  réponse 2 de ${p.me}  ` }));
      }
      const ask = (await R(s.tv, (r) => r.game?.phase === 'ask', 8000)).room.game;
      assert.equal(ask.count, 6);
      assert.equal(ask.author, undefined, 'auteur caché');
      const author = s.ps.find((p) => ask.text.endsWith(p.me));
      const others = s.ps.filter((p) => p !== author);
      author.send(g({ t: 'qad_guess', r: ask.index, pid: others[0].me })); // l'auteur ne vote pas
      others[0].send(g({ t: 'qad_guess', r: ask.index, pid: author.me }));
      others[1].send(g({ t: 'qad_guess', r: ask.index, pid: others[0].me }));
      const rev = (await R(s.tv, (r) => r.game?.phase === 'reveal')).room.game;
      assert.equal(rev.author, author.me);
      assert.equal(rev.picks[author.me], undefined);
      const gain = (p) => rev.ranking.find((x) => x.pid === p.me).gain;
      assert.equal(gain(others[0]), 200);
      assert.equal(gain(others[1]), 0);
      assert.equal(gain(author), 100);
      void a; void b; void c;
      close(s);
      step('Qui a dit ça ? : 2 questions chacun, réponses nettoyées, auteur caché et sans vote, +200 trouvé, +100 par joueur trompé');
    }

    // ---- Le dernier debout ----
    {
      const s = await salon(['Alice', 'Bob', 'Carla']);
      const [a, b, c] = s.ps;
      await launch(s, 'survie', { rounds: 15 });
      // 1re question : personne ne répond (réponses non booléennes ignorées) → personne ne sort
      const ask0 = (await R(s.tv, (r) => r.game?.phase === 'ask' && r.game.index === 0)).room.game;
      assert.equal(ask0.truth, undefined);
      for (const p of s.ps) p.send(g({ t: 'surv_answer', r: 0, v: 'oui' }));
      let rev = (await R(s.tv, (r) => r.game?.phase === 'reveal' && r.game.index === 0)).room.game;
      assert.equal(rev.saved, true);
      assert.equal(rev.alive.length, 3);
      // 2e question : Alice et Bob répondent l'inverse l'un de l'autre, Carla rien
      await R(s.tv, (r) => r.game?.phase === 'ask' && r.game.index === 1);
      a.send(g({ t: 'surv_answer', r: 1, v: true }));
      b.send(g({ t: 'surv_answer', r: 1, v: false }));
      rev = (await R(s.tv, (r) => r.game?.phase === 'reveal' && r.game.index === 1)).room.game;
      const winner = rev.truth ? a : b;
      assert.deepEqual(rev.alive, [winner.me]);
      assert.equal(rev.out.length, 2);
      assert.deepEqual(rev.winners, [winner.me]);
      assert.equal(rev.ranking.find((x) => x.pid === winner.me).gain, 100 + 500);
      await R(s.tv, (r) => r.game?.phase === 'podium', 8000);
      void c;
      close(s);
      step('Le dernier debout : tous faux = personne ne sort, sans réponse = éliminé, dernier survivant + bonus, podium');
    }

    // ---- Photo roulette ----
    {
      const s = await salon(['Alice', 'Bob', 'Carla']);
      const [a, b, c] = s.ps;
      const jpeg = (n) => Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(60, n)]).toString('base64');
      const http = (path) => fetch(`http://127.0.0.1:${PORT}${path}`);
      await launch(s, 'photoroulette', { per: 3 });
      await R(s.tv, (r) => r.game?.phase === 'intro');
      s.host.send(g({ t: 'game_skip' }));
      await R(s.tv, (r) => r.game?.phase === 'pick');
      b.send(g({ t: 'phr_photo', data: Buffer.from('pas une image du tout').toString('base64') }));
      assert.equal((await b.wait('error')).code, 'bad_photo');
      for (let i = 0; i < 4; i++) a.send(g({ t: 'phr_photo', data: jpeg(i) })); // la 4e est de trop
      b.send(g({ t: 'phr_photo', data: jpeg(9) }));
      b.send(g({ t: 'phr_done' }));                    // Bob s'arrête à 1 photo
      c.send(g({ t: 'phr_photo', data: jpeg(7) }));
      c.send(g({ t: 'phr_clear' }));                   // Carla recommence
      let st = (await R(s.tv, (r) => r.game?.phase === 'pick' && r.game.counts?.[a.me] === 3 && r.game.done?.includes(b.me) && r.game.counts?.[c.me] === 0)).room.game;
      assert.equal(st.counts[a.me], 3);
      assert.deepEqual(st.done.sort(), [a.me, b.me].sort());
      c.send(g({ t: 'phr_photo', data: jpeg(8) }));
      c.send(g({ t: 'phr_done' }));
      const ask = (await R(s.tv, (r) => r.game?.phase === 'ask', 6000)).room.game;
      assert.equal(ask.count, 5);
      assert.equal(ask.owner, undefined, 'propriétaire caché');
      const res = await http(ask.photo);
      assert.equal(res.status, 200);
      assert.equal(res.headers.get('content-type'), 'image/jpeg');
      const n = (await res.arrayBuffer()).byteLength;
      assert.equal(n, 64);
      // On retrouve le propriétaire par le contenu (octet de remplissage)
      const byte = new Uint8Array(await (await http(ask.photo)).arrayBuffer())[10];
      const owner = byte <= 2 ? a : byte === 9 ? b : c;
      const others = s.ps.filter((p) => p !== owner);
      owner.send(g({ t: 'phr_guess', r: ask.index, pid: others[0].me })); // le propriétaire ne vote pas
      others[0].send(g({ t: 'phr_guess', r: ask.index, pid: owner.me }));
      others[1].send(g({ t: 'phr_guess', r: ask.index, pid: others[0].me }));
      const rev = (await R(s.tv, (r) => r.game?.phase === 'reveal')).room.game;
      assert.equal(rev.owner, owner.me);
      assert.equal(rev.picks[owner.me], undefined);
      const gain = (p) => rev.ranking.find((x) => x.pid === p.me).gain;
      assert.ok(gain(others[0]) >= 500);
      assert.equal(gain(others[1]), 0);
      assert.equal(gain(owner), 50);
      // Les photos des manches à venir ne sont pas accessibles, et tout disparaît à la fin
      assert.equal((await http(`/r/${s.code}/0123456789abcdef`)).status, 404);
      s.host.send(g({ t: 'game_end' }));
      await R(s.tv, (r) => r.game?.phase === 'podium');
      s.host.send(g({ t: 'game_skip' }));
      await R(s.tv, (r) => !r.game);
      assert.equal((await http(ask.photo)).status, 404);
      close(s);
      step('Photo roulette : photos vérifiées et limitées, « j’ai fini », recommencer, propriétaire caché et sans vote, photo servie puis effacée à la fin');
    }
  }

  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC :', e);
  process.exitCode = 1;
} finally {
  srv.kill();
  setTimeout(() => process.exit(), 200);
}
