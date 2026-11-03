// Emoji rébus : une suite d'emojis sur la TV (🦁👑 = Le Roi Lion), chacun choisit
// la bonne réponse parmi 4 sur son téléphone. Plus on trouve tôt, plus on marque.
// Contenu dans pb_rebus (sql/12_rebus.sql) : emojis, réponse, catégorie, 3 fausses réponses.
import { db } from '../db.js';
import { fastTimings, loadContent, shuffle } from './common.js';
import { RoundGame } from './round.js';

export const RBS = fastTimings({
  rounds: [6, 10, 15],
  defaultRounds: 10,
  introMs: 6000,
  askMs: 25000,
  revealMs: 6000,
  podiumMs: 25000,
  minPoints: 200,     // bonne réponse
  speedPoints: 800,   // + rapidité (jusqu'à)
});

export class RebusGame extends RoundGame {
  static id = 'rebus';

  static async create(room, opts, hooks) {
    const n = RBS.rounds.includes(opts?.rounds) ? opts.rounds : RBS.defaultRounds;
    const rows = await loadContent(db, room, 'pb_rebus', 'emojis, answer, category, wrong1, wrong2, wrong3, hint', n, 'Aucun rébus en base (sql/12_rebus.sql)');
    return new RebusGame(room, hooks, rows);
  }

  constructor(room, hooks, rows) {
    super(room, hooks, { id: 'rebus', count: rows.length, answerType: 'rbs_pick', ...RBS });
    this.items = rows;
  }

  makeRound(i) {
    const it = this.items[i];
    const choices = shuffle([it.answer, it.wrong1, it.wrong2, it.wrong3]);
    return { emojis: it.emojis, category: it.category, hint: it.hint || '', choices, correct: choices.indexOf(it.answer) };
  }

  accept(p, m) {
    return Number.isInteger(m.choice) && m.choice >= 0 && m.choice < 4 ? m.choice : undefined;
  }

  scoreRound() {
    for (const [pid, a] of this.answers) {
      if (a.v === this.round.correct) this.addPoints(pid, RBS.minPoints + Math.round((RBS.speedPoints * this.speed(a.at)) / 10) * 10);
    }
  }

  publicRound(reveal) {
    // Les emojis et les 4 choix sont l'énigme ; la bonne réponse et l'explication à la fin
    const s = { emojis: this.round.emojis, category: this.round.category, choices: this.round.choices };
    if (reveal) {
      s.correct = this.round.correct;
      s.hint = this.round.hint;
      s.picks = Object.fromEntries([...this.answers].map(([pid, a]) => [pid, a.v]));
    }
    return s;
  }
}
