// Course de réflexes : une série d'épreuves éclair, classement à chaque épreuve.
//   feu     : attendre le vert puis taper le plus vite possible (faux départ = 0)
//   taps    : taper le plus de fois possible en 8 s
//   couleur : toucher la couleur de l'ENCRE du mot affiché (pas le mot)
//   compte  : compter les emojis affichés 3 s, puis choisir le bon nombre
// Les temps de réaction sont mesurés par le téléphone (indépendant du réseau),
// avec des garde-fous côté serveur.
import crypto from 'node:crypto';
import { BaseGame, fastTimings, shuffle } from './common.js';

export const RFX = fastTimings({
  trials: [3, 5, 8],
  defaultTrials: 5,
  introMs: 5000,
  readyMs: 4500,
  feuMinMs: 2000,
  feuMaxMs: 5000,
  feuGoMs: 3000,
  tapsMs: 8000,
  couleurMs: 5000,
  compteShowMs: 3000,
  compteMs: 6000,
  resultMs: 6000,
  podiumMs: 25000,
  points: [500, 400, 300, 200],  // 1er, 2e, 3e, les suivants
  minRt: 80,                     // en dessous : impossible pour un humain
  maxTapsPerSec: 18,
});

export const COLORS = ['rouge', 'bleu', 'jaune', 'vert'];
const EMOJIS = ['🍕', '🐸', '⭐', '🎈', '🍩', '🦄', '⚽', '🍓', '🐱', '🎁'];
const TYPES = ['feu', 'taps', 'couleur', 'compte'];

export class ReflexesGame extends BaseGame {
  static id = 'reflexes';

  static async create(room, opts, hooks) {
    const n = RFX.trials.includes(opts?.trials) ? opts.trials : RFX.defaultTrials;
    // Toutes les épreuves une fois avant de se répéter, jamais deux fois de suite
    const seq = [];
    while (seq.length < n) {
      const pack = shuffle([...TYPES]);
      if (seq.length && pack[0] === seq[seq.length - 1]) pack.push(pack.shift());
      seq.push(...pack);
    }
    return new ReflexesGame(room, seq.slice(0, n), hooks);
  }

  constructor(room, seq, hooks) {
    super(room, hooks);
    this.seq = seq;
    this.index = -1;
    this.trial = null;
    this.podiumMs = RFX.podiumMs;
    this.throttle = null;
  }

  get type() { return this.seq[this.index]; }

  start() {
    this.schedule(RFX.introMs, () => this.nextTrial());
  }

  stop() {
    super.stop();
    clearTimeout(this.throttle);
  }

  // Les taps arrivent très souvent : on regroupe les rediffusions (4 par seconde)
  changedSoon() {
    if (this.throttle) return;
    this.throttle = setTimeout(() => { this.throttle = null; if (!this.over) this.changed(); }, 250);
  }

  nextTrial() {
    this.index++;
    if (this.index >= this.seq.length) return this.podium(RFX.podiumMs);
    this.gains.clear();
    this.trial = { type: this.type, results: new Map(), falseStart: new Set(), startedAt: 0 };
    if (this.type === 'couleur') {
      const word = crypto.randomInt(4);
      let ink = crypto.randomInt(3);
      if (ink >= word) ink++; // l'encre n'est jamais la couleur écrite
      this.trial.word = word;
      this.trial.ink = ink;
    }
    if (this.type === 'compte') {
      const n = 5 + crypto.randomInt(11); // 5 à 15
      const emoji = EMOJIS[crypto.randomInt(EMOJIS.length)];
      // positions sur une grille 6×4, sans doublon
      const cells = shuffle([...Array(24).keys()]).slice(0, n);
      const opts = new Set([n]);
      while (opts.size < 4) {
        const d = n + (crypto.randomInt(2) ? 1 : -1) * (1 + crypto.randomInt(3));
        if (d > 0) opts.add(d);
      }
      Object.assign(this.trial, { n, emoji, cells, options: [...opts].sort((a, b) => a - b) });
    }
    this.phase = 'ready';
    this.schedule(RFX.readyMs, () => this.go());
    this.changed();
  }

  go() {
    const t = this.trial;
    switch (t.type) {
      case 'feu':
        this.phase = 'wait';
        this.schedule(RFX.feuMinMs + crypto.randomInt(RFX.feuMaxMs - RFX.feuMinMs), () => {
          this.phase = 'go';
          t.startedAt = Date.now();
          this.schedule(RFX.feuGoMs, () => this.result());
          this.changed();
        });
        break;
      case 'taps':
        this.phase = 'go';
        t.startedAt = Date.now();
        this.schedule(RFX.tapsMs, () => this.result());
        break;
      case 'couleur':
        this.phase = 'go';
        t.startedAt = Date.now();
        this.schedule(RFX.couleurMs, () => this.result());
        break;
      case 'compte':
        this.phase = 'show';
        this.schedule(RFX.compteShowMs, () => {
          this.phase = 'go';
          t.startedAt = Date.now();
          this.schedule(RFX.compteMs, () => this.result());
          this.changed();
        });
        break;
    }
    this.changed();
  }

  // Temps de réaction annoncé par le téléphone, borné par ce que le serveur a vu
  rt(m) {
    const seen = Date.now() - this.trial.startedAt;
    const v = Number(m.rt);
    if (!Number.isFinite(v)) return seen;
    return Math.max(RFX.minRt, Math.min(Math.round(v), seen + 300));
  }

  allDone() {
    const t = this.trial;
    return this.active().every((p) => t.results.has(p.pid) || t.falseStart.has(p.pid));
  }

  onMessage(p, m) {
    const t = this.trial;
    if (m.t === 'rfx' && t && m.k === this.index) {
      this.onPlayerJoin(p);
      if (t.results.has(p.pid) || t.falseStart.has(p.pid)) {
        // Seul le marathon accepte plusieurs envois (le compteur grimpe)
        if (!(t.type === 'taps' && this.phase === 'go' && t.results.has(p.pid))) return;
      }
      if (t.type === 'feu') {
        if (this.phase === 'wait' || this.phase === 'ready') t.falseStart.add(p.pid);
        else if (this.phase === 'go') t.results.set(p.pid, { rt: this.rt(m), ok: true });
        else return;
      } else if (t.type === 'taps') {
        if (this.phase !== 'go') return;
        const elapsed = (Date.now() - t.startedAt) / 1000;
        const cap = Math.ceil((elapsed + 0.5) * RFX.maxTapsPerSec);
        const n = Math.max(0, Math.min(Math.floor(Number(m.n) || 0), cap));
        const prev = t.results.get(p.pid)?.n || 0;
        t.results.set(p.pid, { n: Math.max(prev, n), ok: true });
        return this.changedSoon();
      } else if (t.type === 'couleur') {
        if (this.phase !== 'go' || !Number.isInteger(m.c)) return;
        t.results.set(p.pid, { rt: this.rt(m), ok: m.c === t.ink, choice: m.c });
      } else if (t.type === 'compte') {
        if (this.phase !== 'go' || !Number.isInteger(m.c)) return;
        t.results.set(p.pid, { rt: this.rt(m), ok: m.c === t.n, choice: m.c });
      }
      if (t.type !== 'taps' && this.allDone()) this.schedule(600, () => this.result());
      this.changed();
      return;
    }
    this.hostCommand(p, m, () => {
      if (this.phase === 'intro' || this.phase === 'result') this.nextTrial();
      else if (this.phase === 'ready') this.go();
      else if (['wait', 'show'].includes(this.phase)) { /* on laisse finir l'attente */ }
      else this.result();
    });
  }

  onPlayerGone() {
    if (this.trial && ['go', 'wait'].includes(this.phase) && this.trial.type !== 'taps'
        && this.active().length && this.allDone()) {
      this.schedule(600, () => this.result());
    }
  }

  // Classement de l'épreuve et points
  result() {
    if (this.phase === 'result') return;
    const t = this.trial;
    const valid = [...t.results].filter(([, r]) => r.ok);
    if (t.type === 'taps') valid.sort((a, b) => b[1].n - a[1].n);
    else valid.sort((a, b) => a[1].rt - b[1].rt);
    t.order = [];
    let place = 0;
    let prevKey = null;
    valid.forEach(([pid, r], i) => {
      const key = t.type === 'taps' ? r.n : r.rt;
      if (key !== prevKey) { place = i; prevKey = key; }
      if (t.type === 'taps' && r.n === 0) return;
      const pts = RFX.points[Math.min(place, RFX.points.length - 1)];
      this.addPoints(pid, pts);
      t.order.push({ pid, place: place + 1, ...r, pts });
    });
    this.phase = 'result';
    const last = this.index === this.seq.length - 1;
    this.schedule(RFX.resultMs, () => (last ? this.podium(RFX.podiumMs) : this.nextTrial()));
    this.changed();
  }

  publicState() {
    const s = { ...this.base('reflexes'), index: this.index, count: this.seq.length };
    const t = this.trial;
    if (!t || this.phase === 'podium' || this.phase === 'intro') return s;
    s.type = t.type;
    s.done = [...t.results.keys()];
    s.falseStart = [...t.falseStart];
    if (t.type === 'taps') s.taps = Object.fromEntries([...t.results].map(([pid, r]) => [pid, r.n]));
    if (t.type === 'couleur' && this.phase !== 'ready') { s.word = t.word; s.ink = t.ink; }
    if (t.type === 'compte') {
      if (this.phase === 'show') { s.emoji = t.emoji; s.cells = t.cells; }
      if (this.phase === 'go' || this.phase === 'result') s.options = t.options;
    }
    if (this.phase === 'result') {
      s.order = t.order;
      if (t.type === 'compte') { s.answer = t.n; s.emoji = t.emoji; s.cells = t.cells; }
    }
    return s;
  }

  playerState(pid) {
    const t = this.trial;
    const r = this.ranking().find((x) => x.pid === pid);
    const mine = t?.results.get(pid);
    return {
      done: !!mine || !!t?.falseStart.has(pid),
      falseStart: !!t?.falseStart.has(pid),
      result: mine ?? null,
      place: this.phase === 'result' ? (t.order.find((o) => o.pid === pid)?.place ?? null) : null,
      gain: this.phase === 'result' ? (this.gains.get(pid) || 0) : null,
      score: r?.score ?? 0,
      rank: r?.rank ?? null,
      players: this.ranking().length,
    };
  }
}
