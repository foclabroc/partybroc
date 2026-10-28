// Le dernier debout : vrai ou faux ? Une erreur (ou pas de réponse) et on est éliminé.
// Si tous les survivants se trompent à la même question, personne ne sort.
// Les éliminés continuent de répondre pour le plaisir (quelques points de consolation).
import { db } from '../db.js';
import { fastTimings, loadContent } from './common.js';
import { RoundGame } from './round.js';

export const SURV = fastTimings({
  rounds: [15, 25, 40],          // nombre maximum de questions
  defaultRounds: 25,
  introMs: 6000,
  askMs: 12000,
  revealMs: 6000,
  podiumMs: 25000,
  survivePoints: 100,
  ghostPoints: 30,
  winnerBonus: 500,
});

export class SurvieGame extends RoundGame {
  static id = 'survie';

  static async create(room, opts, hooks) {
    const n = SURV.rounds.includes(opts?.rounds) ? opts.rounds : SURV.defaultRounds;
    const rows = await loadContent(db, room, 'pb_vf_statements', 'statement, truth, explain', n, 'Aucune affirmation vrai/faux en base');
    return new SurvieGame(room, hooks, rows);
  }

  constructor(room, hooks, rows) {
    super(room, hooks, { id: 'survie', count: rows.length, answerType: 'surv_answer', ...SURV });
    this.items = rows;
    this.alive = new Set(this.active().map((p) => p.pid));
    this.out = [];          // éliminés à cette question
    this.saved = false;     // tout le monde s'est trompé : personne ne sort
    this.winners = [];
  }

  // Arrivé en cours de partie : pas dans « alive », il répond pour les points de consolation
  isLast() { return this.index >= this.count - 1 || this.alive.size <= 1; }

  makeRound(i) { return this.items[i]; }

  accept(p, m) { return typeof m.v === 'boolean' ? m.v : undefined; }

  scoreRound() {
    const truth = this.round.truth;
    const ok = (pid) => this.answers.get(pid)?.v === truth;
    const aliveNow = [...this.alive].filter((pid) => this.room.players.has(pid));
    const losers = aliveNow.filter((pid) => !ok(pid));
    this.saved = losers.length > 0 && losers.length === aliveNow.length;
    this.out = this.saved ? [] : losers;
    for (const pid of this.out) this.alive.delete(pid);
    for (const pid of this.alive) this.addPoints(pid, SURV.survivePoints);
    for (const [pid] of this.answers) if (!this.alive.has(pid) && !this.out.includes(pid) && ok(pid)) this.addPoints(pid, SURV.ghostPoints);
    if (this.isLast()) {
      this.winners = [...this.alive];
      for (const pid of this.winners) this.addPoints(pid, SURV.winnerBonus);
    }
  }

  publicRound(reveal) {
    const s = { statement: this.round.statement, alive: [...this.alive] };
    if (reveal) {
      s.truth = this.round.truth;
      s.explain = this.round.explain || '';
      s.out = this.out;
      s.saved = this.saved;
      s.winners = this.isLast() ? this.winners : [];
      s.picks = Object.fromEntries([...this.answers].map(([pid, a]) => [pid, a.v]));
    }
    return s;
  }

  playerRound(pid) { return { alive: this.alive.has(pid), outNow: this.phase === 'reveal' && this.out.includes(pid) }; }

  publicState() {
    const s = super.publicState();
    s.alive ??= [...this.alive];
    return s;
  }
}
