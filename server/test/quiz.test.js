// Test d'une partie complète de quiz (délais accélérés, base obligatoire).
//   PB_DB_URL=postgresql://… npm run test:quiz
import assert from 'node:assert/strict';
import { startServer, client } from './lib.js';

if (!process.env.PB_DB_URL) { console.log('PB_DB_URL manquant : test du quiz ignoré'); process.exit(0); }

const PORT = 4198;
const srv = await startServer(PORT, { PB_FAST: '1' });
let ok = 0;
const step = (s) => { ok++; console.log('  ✔', s); };

try {
  const tv = await client(PORT);
  tv.send({ t: 'tv_hello' });
  const { code } = await tv.wait('tv_ok');

  const a = await client(PORT);
  a.send({ t: 'join', code, name: 'Alice' });
  await a.wait('joined');
  const b = await client(PORT);
  b.send({ t: 'join', code, name: 'Bob' });
  await b.wait('joined');

  // Réglage : 5 questions
  a.send({ t: 'select_game', game: 'quiz' });
  a.send({ t: 'game_option', key: 'count', value: 5 });
  await tv.room((r) => r.selectedGame === 'quiz' && r.options.count === 5);
  b.send({ t: 'game_option', key: 'count', value: 20 }); // pas l'hôte : ignoré
  a.send({ t: 'game_option', key: 'count', value: 7 });  // valeur interdite : ignorée
  step("Réglage du nombre de questions (hôte seulement, valeurs permises)");

  b.send({ t: 'start_game' });
  a.send({ t: 'start_game' });
  let r = (await tv.room((r) => r.game?.phase === 'intro')).room;
  assert.equal(r.phase, 'game');
  assert.equal(r.game.count, 5);
  step('Partie lancée par l’hôte, intro affichée');

  const seen = new Set();
  let totalA = 0, totalB = 0;
  for (let i = 0; i < 5; i++) {
    r = (await tv.room((r) => r.game?.phase === 'question' && r.game.index === i, 5000)).room;
    const g = r.game;
    assert.equal(g.answers.length, 4);
    assert.ok(!('correct' in g) && !('picks' in g), 'la bonne réponse ne doit pas fuiter');
    assert.ok(!seen.has(g.question)); seen.add(g.question);

    a.send({ t: 'game_msg', m: { t: 'quiz_answer', q: i, choice: 0 } });
    a.send({ t: 'game_msg', m: { t: 'quiz_answer', q: i, choice: 1 } }); // 2e réponse ignorée
    const youA = (await a.room((r, you) => r.game?.phase === 'question' && r.game.index === i && you?.choice !== null)).you;
    assert.equal(youA.choice, 0);
    b.send({ t: 'game_msg', m: { t: 'quiz_answer', q: i + 1, choice: 1 } }); // mauvaise question : ignorée
    b.send({ t: 'game_msg', m: { t: 'quiz_answer', q: i, choice: 1 } });

    const rev = (await tv.room((r) => r.game?.phase === 'reveal' && r.game.index === i, 3000)).room.game;
    assert.equal(rev.picks[r.players[0].pid], 0);
    const ga = rev.ranking.find((x) => x.pid === r.players[0].pid).gain;
    const gb = rev.ranking.find((x) => x.pid === r.players[1].pid).gain;
    if (rev.correct === 0) assert.ok(ga >= 500 && gb === 0); else assert.equal(ga, 0);
    if (rev.correct === 1) assert.ok(gb >= 500 && ga === 0); else assert.equal(gb, 0);
    totalA += ga; totalB += gb;
  }
  step('5 questions différentes, réponse cachée jusqu’à la révélation, 1 seule réponse par joueur');
  step('Révélation immédiate quand tout le monde a répondu, points seulement pour la bonne réponse');

  r = (await tv.room((r) => r.game?.phase === 'podium', 5000)).room;
  assert.equal(r.game.ranking.find((x) => x.pid === r.players[0].pid).score, totalA);
  step(`Podium : Alice ${totalA}, Bob ${totalB}`);

  tv.flush();
  a.send({ t: 'game_msg', m: { t: 'game_skip' } }); // l'hôte revient au salon
  r = (await tv.room((r) => r.phase === 'lobby' && r.game === null)).room;
  assert.equal(r.players[0].score, totalA);
  assert.equal(r.players[1].score, totalB);
  step('Retour au salon, points ajoutés au score de la soirée');

  // 2e partie : aucune question déjà posée
  tv.flush();
  a.send({ t: 'start_game' });
  for (let i = 0; i < 5; i++) {
    const g = (await tv.room((r) => r.game?.phase === 'question' && r.game.index === i, 5000)).room.game;
    assert.ok(!seen.has(g.question), 'question déjà posée ce soir');
    if (i === 1) {
      a.send({ t: 'game_msg', m: { t: 'game_end' } });
      break;
    }
  }
  await tv.room((r) => r.game?.phase === 'podium');
  step('2e partie sans question déjà posée, arrêt anticipé par l’hôte');

  // Un joueur qui part pendant une question ne bloque pas la partie
  tv.flush();
  a.send({ t: 'game_msg', m: { t: 'game_skip' } });
  await tv.room((r) => r.phase === 'lobby');
  tv.flush();
  a.send({ t: 'start_game' });
  await tv.room((r) => r.game?.phase === 'question');
  a.send({ t: 'game_msg', m: { t: 'quiz_answer', q: 0, choice: 2 } });
  b.close();
  await tv.room((r) => r.game?.phase === 'reveal' && r.game.index === 0, 2500);
  step('Bob se déconnecte pendant la question : révélation sans l’attendre');

  for (const c of [a, tv]) c.close();
  console.log(`\n${ok} étapes OK`);
} catch (e) {
  console.error('ÉCHEC', e);
  process.exitCode = 1;
} finally {
  srv.kill('SIGTERM');
}
