// Vrai ou Bluff : le jeu dit en secret à chaque joueur s'il doit raconter une anecdote VRAIE
// sur lui ou inventer un BLUFF. Chacun l'écrit, puis la TV les montre une par une : l'auteur
// la défend à voix haute, les autres votent Vrai ou Bluff (on peut changer d'avis jusqu'à la fin).
// La consigne (vrai / bluff) d'un joueur ne quitte le serveur que vers son téléphone,
// et n'apparaît dans l'état public qu'à la révélation.
import { cleanText, fastTimings, shuffle } from './common.js';
import { RoundGame } from './round.js';

export const BLF = fastTimings({
  writes: ['60 s', '90 s', '120 s'],
  defaultWrite: '90 s',
  votes: ['20 s', '30 s', '45 s'],
  defaultVote: '30 s',
  introMs: 7000,
  writeMs: 90000,
  askMs: 30000,
  revealMs: 8000,
  podiumMs: 25000,
  goodPoints: 500,     // bon vote
  speedPoints: 200,    // + rapidité (jusqu'à)
  fooledPoints: 100,   // pour l'auteur, par joueur trompé
  maxLen: 140,
  minLen: 8,
});

// Sujets pour ceux qui sèchent (facultatifs, montrés au-dessus de l'anecdote sur la TV)
export const THEMES = ['🌍 Un voyage', '😳 Une honte', '🎩 Un talent caché', '🤝 Une rencontre', '🧸 Enfance', '🤕 Un accident ridicule', '💼 Au travail', '😱 Une peur', '🍽️ À table', '🐾 Un animal'];

const secs = (v, list, def) => (fastTimings({ durMs: parseInt(list.includes(v) ? v : def, 10) * 1000 }).durMs);

// Moitié vrais, moitié bluffs (au hasard pour l'impair), jamais tous pareils dès 2 joueurs
export function secrets(pids) {
  const n = pids.length;
  const nv = n === 1 ? (Math.random() < 0.5 ? 1 : 0) : Math.floor(n / 2) + (n % 2 && Math.random() < 0.5 ? 1 : 0);
  const list = shuffle([...Array(nv).fill('v'), ...Array(n - nv).fill('b')]);
  return new Map(pids.map((pid, i) => [pid, list[i]]));
}

export class BluffGame extends RoundGame {
  static id = 'bluff';

  static async create(room, opts, hooks) {
    return new BluffGame(room, hooks, opts);
  }

  constructor(room, hooks, opts) {
    super(room, hooks, { id: 'bluff', count: 0, answerType: 'blf_vote', ...BLF, askMs: secs(opts?.vote, BLF.votes, BLF.defaultVote) });
    this.writeMs = secs(opts?.ecriture, BLF.writes, BLF.defaultWrite);
    this.secret = secrets(this.active().map((p) => p.pid));
    this.written = new Map();   // pid -> { text, theme }
    this.entries = [];
  }

  start() {
    this.schedule(BLF.introMs, () => this.write());
  }

  write() {
    this.phase = 'write';
    this.schedule(this.writeMs, () => this.build());
    this.changed();
  }

  allWritten() { return this.active().every((x) => !this.secret.has(x.pid) || this.written.has(x.pid)); }

  // Une anecdote par joueur encore là, dans un ordre au hasard
  build() {
    if (this.phase !== 'write') return;
    this.entries = shuffle([...this.written].filter(([pid]) => this.room.players.has(pid)).map(([pid, w]) => ({ author: pid, ...w, truth: this.secret.get(pid) })));
    this.count = this.entries.length;
    if (this.count === 0) return this.podium(BLF.podiumMs);
    this.next();
  }

  makeRound(i) { return this.entries[i]; }

  answerers() { return this.active().filter((p) => p.pid !== this.round?.author); }

  accept(p, m) { return m.v === 'v' || m.v === 'b' ? m.v : undefined; }

  // Pas de révélation dès que tout le monde a voté : l'auteur a tout le temps pour se défendre
  // (l'hôte peut passer à la suite depuis son menu)
  checkAll() {}

  scoreRound() {
    const { author, truth } = this.round;
    let fooled = 0;
    for (const [pid, a] of this.answers) {
      if (a.v === truth) this.addPoints(pid, BLF.goodPoints + Math.round((BLF.speedPoints * this.speed(a.at)) / 10) * 10);
      else fooled++;
    }
    if (fooled) this.addPoints(author, fooled * BLF.fooledPoints);
  }

  onOther(p, m) {
    if (m.t === 'blf_write') {
      if (this.phase !== 'write' || !this.secret.has(p.pid)) return true;
      const text = cleanText(m.text, BLF.maxLen);
      if ([...text].length < BLF.minLen) return true;
      const theme = Number.isInteger(m.theme) && m.theme >= 0 && m.theme < THEMES.length ? THEMES[m.theme] : null;
      this.written.set(p.pid, { text, theme });
      if (this.allWritten()) this.schedule(800, () => this.build());
      this.changed();
      return true;
    }
    // L'hôte écarte l'anecdote en cours (pas tout public…) : manche suivante, sans points
    if (m.t === 'blf_drop') {
      if (p.pid !== this.room.hostPid || this.phase !== 'ask') return true;
      this.entries.splice(this.index, 1);
      this.count = this.entries.length;
      this.index--;
      if (this.index >= this.count - 1) this.podium(BLF.podiumMs);
      else this.next();
      return true;
    }
    return false;
  }

  onMessage(p, m) {
    if (m.t === 'game_skip' && p.pid === this.room.hostPid) {
      if (this.phase === 'intro') return this.write();
      if (this.phase === 'write') return this.build();
    }
    // Changer d'avis pendant le vote (le temps de rapidité repart de ce moment-là)
    if (m.t === 'blf_vote' && this.phase === 'ask' && m.r === this.index && this.answers.has(p.pid)) {
      const v = this.accept(p, m);
      if (v !== undefined && v !== this.answers.get(p.pid).v) {
        this.answers.set(p.pid, { v, at: Date.now() });
        this.changed();
      }
      return;
    }
    return super.onMessage(p, m);
  }

  onPlayerGone() {
    if (this.phase === 'write' && this.allWritten()) this.schedule(800, () => this.build());
  }

  publicRound(reveal) {
    const s = { author: this.round.author, text: this.round.text, theme: this.round.theme };
    if (reveal) {
      s.truth = this.round.truth;
      s.picks = Object.fromEntries([...this.answers].map(([pid, a]) => [pid, a.v]));
    }
    return s;
  }

  publicState() {
    const s = super.publicState();
    if (this.phase === 'write') s.done = [...this.written.keys()];
    return s;
  }

  playerRound(pid) {
    const r = { mine: this.round?.author === pid && ['ask', 'reveal'].includes(this.phase) };
    if (this.phase === 'intro' || this.phase === 'write' || r.mine) r.secret = this.secret.get(pid) ?? null;
    if (this.phase === 'write') {
      r.themes = THEMES;
      r.written = this.written.get(pid)?.text ?? null;
    }
    return r;
  }
}
