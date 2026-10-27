// Qui de nous ? : une question « Qui est le plus susceptible de… », chacun vote
// pour un autre joueur (vote anonyme). Ceux qui votent comme la majorité marquent.
import { db } from '../db.js';
import { BaseGame, fastTimings, loadContent } from './common.js';

export const QDN = fastTimings({
  rounds: [5, 8, 12],
  defaultRounds: 8,
  introMs: 5000,
  voteMs: 20000,
  revealMs: 8000,
  podiumMs: 25000,
  majorityPoints: 100,  // tu as voté comme le groupe
  starPoints: 50,       // le plus désigné gagne aussi un peu (pour rire)
});

export class QuiDeNousGame extends BaseGame {
  static id = 'quidenous';

  static async create(room, opts, hooks) {
    const n = QDN.rounds.includes(opts?.rounds) ? opts.rounds : QDN.defaultRounds;
    const rows = await loadContent(db, room, 'pb_qdn_prompts', 'prompt', n, 'Aucune question « Qui de nous ? » en base');
    return new QuiDeNousGame(room, rows.map((r) => r.prompt), hooks);
  }

  constructor(room, prompts, hooks) {
    super(room, hooks);
    this.prompts = prompts;
    this.index = -1;
    this.votes = new Map(); // voteur -> cible
    this.tally = [];
    this.winners = [];
    this.podiumMs = QDN.podiumMs;
  }

  start() {
    this.schedule(QDN.introMs, () => this.next());
  }

  next() {
    this.index++;
    if (this.index >= this.prompts.length) return this.podium(QDN.podiumMs);
    this.votes.clear();
    this.gains.clear();
    this.phase = 'vote';
    this.schedule(QDN.voteMs, () => this.reveal());
    this.changed();
  }

  reveal() {
    if (this.phase !== 'vote') return;
    this.phase = 'reveal';
    const counts = new Map();
    for (const target of this.votes.values()) counts.set(target, (counts.get(target) || 0) + 1);
    this.tally = [...counts.entries()].map(([pid, count]) => ({ pid, count })).sort((a, b) => b.count - a.count);
    const top = this.tally[0]?.count || 0;
    this.winners = this.tally.filter((t) => t.count === top && top > 0).map((t) => t.pid);
    // Points : tu as voté pour (un des) plus désigné(s)
    for (const [voter, target] of this.votes) if (this.winners.includes(target)) this.addPoints(voter, QDN.majorityPoints);
    for (const w of this.winners) this.addPoints(w, QDN.starPoints);
    const last = this.index === this.prompts.length - 1;
    this.schedule(QDN.revealMs, () => (last ? this.podium(QDN.podiumMs) : this.next()));
    this.changed();
  }

  onMessage(p, m) {
    if (m.t === 'qdn_vote') {
      if (this.phase !== 'vote' || m.r !== this.index || this.votes.has(p.pid)) return;
      if (typeof m.pid !== 'string' || m.pid === p.pid || !this.room.players.has(m.pid)) return;
      this.votes.set(p.pid, m.pid);
      this.onPlayerJoin(p);
      if (this.active().every((x) => this.votes.has(x.pid))) this.schedule(700, () => this.reveal());
      this.changed();
      return;
    }
    this.hostCommand(p, m, () => {
      if (this.phase === 'intro' || this.phase === 'reveal') this.next();
      else if (this.phase === 'vote') this.reveal();
    });
  }

  onPlayerGone() {
    if (this.phase === 'vote' && this.active().length && this.active().every((x) => this.votes.has(x.pid))) {
      this.schedule(700, () => this.reveal());
    }
  }

  publicState() {
    const s = { ...this.base('quidenous'), index: this.index, count: this.prompts.length };
    if (this.phase === 'vote' || this.phase === 'reveal') {
      s.prompt = this.prompts[this.index];
      s.voted = [...this.votes.keys()]; // qui a voté, jamais pour qui
    }
    if (this.phase === 'reveal') {
      s.tally = this.tally;
      s.winners = this.winners;
      s.votes = this.votes.size;
    }
    return s;
  }

  playerState(pid) {
    const r = this.ranking().find((x) => x.pid === pid);
    return {
      vote: this.votes.get(pid) ?? null,
      gain: this.phase === 'reveal' ? (this.gains.get(pid) || 0) : null,
      score: r?.score ?? 0,
      rank: r?.rank ?? null,
      players: this.ranking().length,
    };
  }
}
