// Réponses drôles : chacun complète la phrase sur son téléphone, puis tout le
// monde vote (anonymement) pour la réponse la plus drôle. 100 points par vote.
import { db } from '../db.js';
import { BaseGame, cleanText, fastTimings, loadContent, shuffle } from './common.js';

export const DRL = fastTimings({
  rounds: [3, 5, 8],
  defaultRounds: 5,
  maxLen: 60,
  introMs: 6000,
  writeMs: 60000,
  voteMs: 25000,
  revealMs: 9000,
  podiumMs: 25000,
  votePoints: 100,
  bestBonus: 200,       // la réponse la plus votée
  unanimousBonus: 300,  // tout le monde a voté pour elle
});

export class DrolesGame extends BaseGame {
  static id = 'droles';

  static async create(room, opts, hooks) {
    const n = DRL.rounds.includes(opts?.rounds) ? opts.rounds : DRL.defaultRounds;
    const rows = await loadContent(db, room, 'pb_drl_prompts', 'prompt', n, 'Aucune phrase « Réponses drôles » en base');
    return new DrolesGame(room, rows.map((r) => r.prompt), hooks);
  }

  constructor(room, prompts, hooks) {
    super(room, hooks);
    this.prompts = prompts;
    this.index = -1;
    this.answers = new Map(); // pid -> texte
    this.order = [];          // [{author, text}] mélangé pour le vote
    this.votes = new Map();   // voteur -> index dans order
    this.podiumMs = DRL.podiumMs;
  }

  start() {
    this.schedule(DRL.introMs, () => this.next());
  }

  next() {
    this.index++;
    if (this.index >= this.prompts.length) return this.podium(DRL.podiumMs);
    this.answers.clear();
    this.votes.clear();
    this.order = [];
    this.gains.clear();
    this.phase = 'write';
    this.schedule(DRL.writeMs, () => this.startVote());
    this.changed();
  }

  startVote() {
    if (this.phase !== 'write') return;
    this.order = shuffle([...this.answers].map(([author, text]) => ({ author, text })));
    // Moins de 2 réponses : rien à départager
    if (this.order.length < 2) return this.reveal();
    this.phase = 'vote';
    this.schedule(DRL.voteMs, () => this.reveal());
    this.changed();
  }

  // Ceux qui peuvent voter : connectés, et il existe au moins une réponse qui n'est pas la leur
  voters() {
    return this.active().filter((p) => this.order.some((a) => a.author !== p.pid));
  }

  reveal() {
    if (this.phase !== 'write' && this.phase !== 'vote') return;
    if (this.phase === 'write') this.order = shuffle([...this.answers].map(([author, text]) => ({ author, text })));
    this.phase = 'reveal';
    const counts = this.order.map(() => 0);
    for (const i of this.votes.values()) counts[i]++;
    this.order.forEach((a, i) => {
      a.votes = counts[i];
      a.voters = [...this.votes].filter(([, v]) => v === i).map(([pid]) => pid);
      if (counts[i]) this.addPoints(a.author, counts[i] * DRL.votePoints);
    });
    const top = Math.max(0, ...counts);
    if (top > 0) {
      const best = this.order.filter((a) => a.votes === top);
      const unanimous = best.length === 1 && this.votes.size >= 2 && top === this.votes.size;
      for (const a of best) {
        a.best = true;
        a.unanimous = unanimous;
        this.addPoints(a.author, unanimous ? DRL.unanimousBonus : DRL.bestBonus);
      }
    }
    const last = this.index === this.prompts.length - 1;
    this.schedule(DRL.revealMs, () => (last ? this.podium(DRL.podiumMs) : this.next()));
    this.changed();
  }

  onMessage(p, m) {
    if (m.t === 'drl_answer') {
      if (this.phase !== 'write' || m.r !== this.index) return;
      const text = cleanText(m.text, DRL.maxLen);
      if (!text) return;
      this.answers.set(p.pid, text); // on peut corriger tant que l'écriture dure
      this.onPlayerJoin(p);
      if (this.active().every((x) => this.answers.has(x.pid))) this.schedule(800, () => this.startVote());
      this.changed();
      return;
    }
    if (m.t === 'drl_vote') {
      if (this.phase !== 'vote' || m.r !== this.index || this.votes.has(p.pid)) return;
      const i = m.a;
      if (!Number.isInteger(i) || i < 0 || i >= this.order.length) return;
      if (this.order[i].author === p.pid) return; // pas pour soi
      this.votes.set(p.pid, i);
      if (this.voters().every((x) => this.votes.has(x.pid))) this.schedule(700, () => this.reveal());
      this.changed();
      return;
    }
    this.hostCommand(p, m, () => {
      if (this.phase === 'intro' || this.phase === 'reveal') this.next();
      else if (this.phase === 'write') this.startVote();
      else if (this.phase === 'vote') this.reveal();
    });
  }

  onPlayerGone() {
    if (this.phase === 'write' && this.active().length && this.active().every((x) => this.answers.has(x.pid))) {
      this.schedule(800, () => this.startVote());
    } else if (this.phase === 'vote' && this.voters().length && this.voters().every((x) => this.votes.has(x.pid))) {
      this.schedule(700, () => this.reveal());
    }
  }

  publicState() {
    const s = { ...this.base('droles'), index: this.index, count: this.prompts.length };
    if (['write', 'vote', 'reveal'].includes(this.phase)) s.prompt = this.prompts[this.index];
    if (this.phase === 'write') s.answered = [...this.answers.keys()];
    if (this.phase === 'vote') {
      s.answers = this.order.map((a, i) => ({ i, text: a.text })); // auteurs cachés
      s.voted = [...this.votes.keys()];
    }
    if (this.phase === 'reveal') {
      s.answers = this.order.map((a, i) => ({
        i, text: a.text, author: a.author, votes: a.votes, voters: a.voters, best: !!a.best, unanimous: !!a.unanimous,
      }));
    }
    return s;
  }

  playerState(pid) {
    const r = this.ranking().find((x) => x.pid === pid);
    return {
      answer: this.answers.get(pid) ?? null,
      mine: this.phase === 'vote' ? this.order.findIndex((a) => a.author === pid) : null,
      vote: this.votes.get(pid) ?? null,
      gain: this.phase === 'reveal' ? (this.gains.get(pid) || 0) : null,
      score: r?.score ?? 0,
      rank: r?.rank ?? null,
      players: this.ranking().length,
    };
  }
}
