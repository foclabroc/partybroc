// Qui a dit ça ? : chacun répond en secret à 2 questions perso, puis la TV affiche les
// réponses une par une et tout le monde devine qui l'a écrite (l'auteur, lui, se tait).
// L'auteur n'est JAMAIS envoyé avant la révélation.
import { db } from '../db.js';
import { cleanText, fastTimings, loadContent, shuffle } from './common.js';
import { RoundGame } from './round.js';

export const QAD = fastTimings({
  rounds: [6, 10, 15],
  defaultRounds: 10,
  perPlayer: 2,
  introMs: 6000,
  writeMs: 90000,
  askMs: 20000,
  revealMs: 7000,
  podiumMs: 25000,
  findPoints: 200,     // bonne personne trouvée
  fooledPoints: 100,   // pour l’auteur, par joueur qui s’est trompé (pousse à brouiller les pistes)
  maxLen: 60,
});

export class QuiAditGame extends RoundGame {
  static id = 'quiadit';

  static async create(room, opts, hooks) {
    const players = [...room.players.values()].filter((p) => p.connected);
    const n = Math.max(QAD.perPlayer, players.length * QAD.perPlayer);
    const rows = await loadContent(db, room, 'pb_qad_prompts', 'prompt', n, 'Aucune question « Qui a dit ça ? » en base');
    return new QuiAditGame(room, hooks, rows.map((r) => r.prompt), opts);
  }

  constructor(room, hooks, prompts, opts) {
    const wanted = QAD.rounds.includes(opts?.rounds) ? opts.rounds : QAD.defaultRounds;
    super(room, hooks, { id: 'quiadit', count: 0, answerType: 'qad_guess', ...QAD });
    this.wanted = wanted;
    this.prompts = new Map();   // pid -> [question, question]
    this.written = new Map();   // pid -> [réponse ou null, …]
    let k = 0;
    for (const p of this.active()) {
      const mine = [];
      for (let i = 0; i < QAD.perPlayer; i++) mine.push(prompts[k++ % prompts.length]);
      this.prompts.set(p.pid, mine);
      this.written.set(p.pid, mine.map(() => null));
    }
    this.entries = [];
  }

  start() {
    this.schedule(QAD.introMs, () => this.write());
  }

  write() {
    this.phase = 'write';
    this.schedule(QAD.writeMs, () => this.build());
    this.changed();
  }

  doneWriting(pid) { return (this.written.get(pid) || []).every((t) => t); }

  // Les réponses deviennent les manches : mélangées, sans deux fois le même auteur d'affilée si possible
  build() {
    if (this.phase !== 'write') return;
    const all = [];
    for (const [pid, list] of this.written) {
      list.forEach((text, i) => { if (text && this.room.players.has(pid)) all.push({ author: pid, prompt: this.prompts.get(pid)[i], text }); });
    }
    const pool = shuffle(all);
    const ordered = [];
    while (pool.length) {
      const i = pool.findIndex((e) => e.author !== ordered.at(-1)?.author);
      ordered.push(...pool.splice(i < 0 ? 0 : i, 1));
    }
    this.entries = ordered.slice(0, this.wanted);
    this.count = this.entries.length;
    if (this.count === 0) return this.podium(QAD.podiumMs);
    this.next();
  }

  makeRound(i) { return this.entries[i]; }

  answerers() { return this.active().filter((p) => p.pid !== this.round?.author); }

  accept(p, m) {
    return typeof m.pid === 'string' && m.pid !== p.pid && this.room.players.has(m.pid) ? m.pid : undefined;
  }

  scoreRound() {
    const author = this.round.author;
    let fooled = 0;
    for (const [pid, a] of this.answers) {
      if (a.v === author) this.addPoints(pid, QAD.findPoints);
      else fooled++;
    }
    if (fooled) this.addPoints(author, fooled * QAD.fooledPoints);
  }

  onOther(p, m) {
    if (m.t !== 'qad_write') return false;
    if (this.phase !== 'write' || !this.written.has(p.pid)) return true;
    const i = m.i;
    const list = this.written.get(p.pid);
    if (!Number.isInteger(i) || i < 0 || i >= list.length) return true;
    const text = cleanText(m.text, QAD.maxLen);
    if (!text) return true;
    list[i] = text;
    if (this.active().every((x) => !this.written.has(x.pid) || this.doneWriting(x.pid))) this.schedule(800, () => this.build());
    this.changed();
    return true;
  }

  onPlayerGone() {
    if (this.phase === 'write' && this.active().every((x) => !this.written.has(x.pid) || this.doneWriting(x.pid))) this.schedule(800, () => this.build());
    else super.onPlayerGone();
  }

  // L'hôte : depuis l'intro on passe à l'écriture (pas aux manches, qui n'existent pas encore),
  // et il peut couper l'écriture
  onMessage(p, m) {
    if (m.t === 'game_skip' && p.pid === this.room.hostPid) {
      if (this.phase === 'intro') return this.write();
      if (this.phase === 'write') return this.build();
    }
    return super.onMessage(p, m);
  }

  publicRound(reveal) {
    const s = { prompt: this.round.prompt, text: this.round.text };
    if (reveal) {
      s.author = this.round.author;
      s.picks = Object.fromEntries([...this.answers].map(([pid, a]) => [pid, a.v]));
    }
    return s;
  }

  publicState() {
    const s = super.publicState();
    if (this.phase === 'write') s.done = [...this.written.keys()].filter((pid) => this.doneWriting(pid));
    return s;
  }

  playerRound(pid) {
    const r = { mine: this.round?.author === pid && ['ask', 'reveal'].includes(this.phase) };
    if (this.phase === 'write') {
      r.prompts = this.prompts.get(pid) || [];
      r.written = this.written.get(pid) || [];
    }
    return r;
  }
}
