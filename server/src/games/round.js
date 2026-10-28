// Base des jeux « par manches » : intro → (montrer) → question → révélation → … → podium.
// Chaque jeu fournit : makeRound(i), accept(p, m) (valeur de la réponse ou undefined),
// scoreRound(), publicRound(reveal), et éventuellement playerRound(pid).
// La bonne réponse ne doit apparaître dans publicRound() que quand reveal est vrai.
import { BaseGame } from './common.js';

export class RoundGame extends BaseGame {
  constructor(room, hooks, cfg) {
    super(room, hooks);
    this.id = cfg.id;
    this.count = cfg.count;
    this.cfg = cfg;               // introMs, showMs (facultatif), askMs, revealMs, podiumMs
    this.podiumMs = cfg.podiumMs;
    this.answerType = cfg.answerType;
    this.index = -1;
    this.round = null;
    this.answers = new Map();     // pid -> { v, at }
    this.askStart = 0;
  }

  start() {
    this.schedule(this.cfg.introMs, () => this.next());
  }

  // Dernière manche ? (les jeux peuvent finir plus tôt, ex. un seul survivant)
  isLast() { return this.index >= this.count - 1; }

  next() {
    this.index++;
    if (this.index >= this.count) return this.podium(this.podiumMs);
    this.answers.clear();
    this.gains.clear();
    this.round = this.makeRound(this.index);
    if (this.cfg.showMs) {
      // Mémoire : on montre d'abord, la question vient ensuite
      this.phase = 'show';
      this.schedule(this.cfg.showMs, () => this.ask());
      this.changed();
    } else {
      this.ask();
    }
  }

  ask() {
    this.phase = 'ask';
    this.askStart = Date.now();
    this.schedule(this.cfg.askMs, () => this.reveal());
    this.changed();
  }

  reveal() {
    if (this.phase !== 'ask') return;
    this.phase = 'reveal';
    this.scoreRound();
    this.schedule(this.cfg.revealMs, () => (this.isLast() ? this.podium(this.podiumMs) : this.next()));
    this.changed();
  }

  // Qui doit répondre (par défaut : tous les joueurs connectés)
  answerers() { return this.active(); }

  // 1 = réponse immédiate, 0 = au dernier moment
  speed(at) { return Math.max(0, 1 - (at - this.askStart) / this.cfg.askMs); }

  checkAll() {
    const need = this.answerers();
    if (this.phase === 'ask' && need.length && need.every((x) => this.answers.has(x.pid))) this.schedule(600, () => this.reveal());
  }

  onMessage(p, m) {
    if (m.t === this.answerType) {
      if (this.phase !== 'ask' || m.r !== this.index || this.answers.has(p.pid)) return;
      if (!this.answerers().some((x) => x.pid === p.pid)) return;
      const v = this.accept(p, m);
      if (v === undefined) return;
      this.answers.set(p.pid, { v, at: Date.now() });
      this.onPlayerJoin(p);
      this.checkAll();
      this.changed();
      return;
    }
    if (this.onOther?.(p, m)) return;
    this.hostCommand(p, m, () => {
      if (this.phase === 'intro' || this.phase === 'reveal') (this.phase === 'reveal' && this.isLast() ? this.podium(this.podiumMs) : this.next());
      else if (this.phase === 'show') this.ask();
      else if (this.phase === 'ask') this.reveal();
    });
  }

  onPlayerGone() { this.checkAll(); }

  publicState() {
    const s = { ...this.base(this.id), index: this.index, count: this.count };
    if (this.round && ['show', 'ask', 'reveal'].includes(this.phase)) {
      Object.assign(s, this.publicRound(this.phase === 'reveal'));
      s.answered = [...this.answers.keys()]; // qui a répondu, jamais quoi
    }
    return s;
  }

  playerState(pid) {
    const r = this.ranking().find((x) => x.pid === pid);
    return {
      answer: this.answers.get(pid)?.v ?? null,
      gain: this.phase === 'reveal' ? (this.gains.get(pid) || 0) : null,
      score: r?.score ?? 0,
      rank: r?.rank ?? null,
      players: this.ranking().length,
      ...(this.playerRound?.(pid) || {}),
    };
  }
}
