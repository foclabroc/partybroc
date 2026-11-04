// Loto : la TV tire les boules (1 à 90), chacun a son carton (ou 2) sur son téléphone.
// Carton français : 3 lignes × 9 colonnes, 15 numéros, 5 par ligne ; colonne 1 : 1-9,
// colonne 2 : 10-19 … colonne 9 : 80-90 ; les cases vides sont vertes.
// On joue la quine (1 ligne), la double quine (2 lignes), puis le carton plein (3 lignes).
// Marquage « À la main » : on touche ses numéros et on crie « Quine ! » soi-même (le serveur
// vérifie avec les boules tirées ; faux = 5 s sans pouvoir réannoncer). « Automatique » : tout
// est marqué et annoncé par le serveur. Plusieurs gagnants pour la même boule = gain partagé
// (chacun a tous les points). Les cartons ne sont que dans playerState.
import crypto from 'node:crypto';
import { BaseGame, fastTimings, shuffle } from './common.js';

export const LOTO = fastTimings({
  cartons: [1, 2],
  defaultCartons: 1,
  speeds: ['Lente', 'Normale', 'Rapide'],
  defaultSpeed: 'Normale',
  marks: ['À la main', 'Automatique'],
  defaultMarks: 'À la main',
  introMs: 8000,
  winMs: 6000,            // pause sur la quine / le carton (les autres gagnants de la même boule y entrent aussi)
  lockMs: 5000,           // faux « Quine ! »
  podiumMs: 25000,
});
const SPEED_MS = { Lente: 9000, Normale: 6000, Rapide: 4000 };
export const PRIZES = [
  { id: 'quine', title: 'Quine', lines: 1, points: 300 },
  { id: 'double', title: 'Double quine', lines: 2, points: 500 },
  { id: 'plein', title: 'Carton plein', lines: 3, points: 1000 },
];
// Quelques surnoms du loto, lus par l'animateur et écrits sous la boule
export const NICKNAMES = { 1: 'le petit', 22: 'les deux canards', 33: 'l’âge du Christ', 90: 'le grand-père' };

// Un carton : rows[3][9], 0 = case vide
export function makeCarton() {
  for (let attempt = 0; attempt < 500; attempt++) {
    // combien de numéros par colonne (1 à 3, 15 en tout)
    const count = Array(9).fill(1);
    let left = 6;
    while (left > 0) {
      const c = crypto.randomInt(9);
      if (count[c] < 3) { count[c]++; left--; }
    }
    // dans quelles lignes : chaque ligne doit avoir 5 numéros
    const rows = [[], [], []];
    const grid = [Array(9).fill(0), Array(9).fill(0), Array(9).fill(0)];
    const perRow = [0, 0, 0];
    let ok = true;
    // colonnes à 3 d'abord, puis à 2, puis à 1 : on remplit les lignes les moins pleines
    const order = shuffle([...Array(9).keys()]).sort((a, b) => count[b] - count[a]);
    for (const c of order) {
      const pick = shuffle([0, 1, 2]).sort((a, b) => perRow[a] - perRow[b]).slice(0, count[c]);
      for (const r of pick) {
        if (perRow[r] >= 5) { ok = false; break; }
        perRow[r]++;
        rows[r].push(c);
      }
      if (!ok) break;
    }
    if (!ok || perRow.some((n) => n !== 5)) continue;
    // les numéros de chaque colonne, rangés de haut en bas
    for (let c = 0; c < 9; c++) {
      const lo = c === 0 ? 1 : c * 10;
      const hi = c === 8 ? 90 : c * 10 + 9;
      const pool = shuffle(Array.from({ length: hi - lo + 1 }, (_, i) => lo + i)).slice(0, count[c]).sort((a, b) => a - b);
      const rs = [0, 1, 2].filter((r) => rows[r].includes(c));
      rs.forEach((r, i) => { grid[r][c] = pool[i]; });
    }
    return grid;
  }
  throw new Error('carton impossible');
}

// Nombre de lignes complètes d'un carton avec les boules tirées
export function fullLines(grid, drawn) {
  return grid.filter((row) => row.every((n) => n === 0 || drawn.has(n))).length;
}

// Ce qui manque au mieux pour avoir `lines` lignes
function missingFor(grid, drawn, lines) {
  const miss = grid.map((row) => row.filter((n) => n && !drawn.has(n)).length).sort((a, b) => a - b);
  return miss.slice(0, lines).reduce((a, b) => a + b, 0);
}

export class LotoGame extends BaseGame {
  static id = 'loto';

  static async create(room, opts, hooks) {
    return new LotoGame(room, hooks, opts);
  }

  constructor(room, hooks, opts = {}) {
    super(room, hooks);
    this.podiumMs = LOTO.podiumMs;
    const n = LOTO.cartons.includes(opts.cartons) ? opts.cartons : LOTO.defaultCartons;
    this.speed = SPEED_MS[opts.vitesse] ?? SPEED_MS[LOTO.defaultSpeed];
    if (process.env.PB_FAST) this.speed = Math.round(this.speed / 10);
    this.auto = opts.marquage === 'Automatique';
    this.bag = shuffle(Array.from({ length: 90 }, (_, i) => i + 1));
    this.drawn = [];
    this.drawnSet = new Set();
    this.cards = new Map();
    this.marks = new Map();
    for (const p of this.active()) {
      this.cards.set(p.pid, Array.from({ length: n }, () => makeCarton()));
      this.marks.set(p.pid, new Set());
    }
    this.stage = 0;            // prix en jeu : PRIZES[stage]
    this.winners = [];         // { prize, pids }
    this.lock = new Map();     // pid -> fin du blocage (faux « Quine ! »)
    this.event = null;
    this.seq = 0;
  }

  get prize() { return PRIZES[this.stage] ?? null; }

  start() {
    this.schedule(LOTO.introMs, () => this.draw());
  }

  note(k, extra = {}) { this.event = { seq: ++this.seq, k, ...extra }; }

  draw() {
    if (this.over) return;
    const n = this.bag.pop();
    if (n === undefined) return this.end();
    this.drawn.push(n);
    this.drawnSet.add(n);
    this.phase = 'draw';
    if (this.auto) {
      for (const [pid, m] of this.marks) if (this.cards.get(pid).some((g) => g.some((row) => row.includes(n)))) m.add(n);
      if (this.autoWin()) return;
    }
    this.schedule(this.speed, () => this.draw());
    this.changed();
  }

  // Marquage automatique : le serveur annonce lui-même les gagnants
  autoWin() {
    const won = [...this.cards]
      .filter(([pid]) => this.room.players.has(pid))
      .filter(([, gs]) => gs.some((g) => fullLines(g, this.drawnSet) >= this.prize.lines))
      .map(([pid]) => pid);
    if (!won.length) return false;
    this.win(won);
    return true;
  }

  // Quine / double quine / carton plein pour ces joueurs
  win(pids) {
    const prize = this.prize;
    const w = { prize: prize.id, title: prize.title, pids: [], at: this.drawn.length };
    this.winners.push(w);
    for (const pid of pids) this.addWinner(w, pid);
    this.phase = 'win';
    this.note('win', { prize: prize.id, pids: w.pids });
    this.schedule(LOTO.winMs, () => this.afterWin());
    this.changed();
  }

  addWinner(w, pid) {
    if (w.pids.includes(pid)) return;
    w.pids.push(pid);
    this.addPoints(pid, PRIZES.find((p) => p.id === w.prize).points);
  }

  afterWin() {
    if (this.phase !== 'win') return;
    this.stage++;
    if (!this.prize) return this.end();
    // Automatique : les boules déjà tirées donnent peut-être déjà le prix suivant
    if (this.auto && this.autoWin()) return;
    this.phase = 'draw';
    this.schedule(Math.round(this.speed / 2), () => this.draw());
    this.changed();
  }

  claim(p) {
    if (this.auto || !this.cards.has(p.pid)) return;
    if ((this.lock.get(p.pid) || 0) > Date.now()) return;
    const last = this.winners[this.winners.length - 1];
    // Pendant la pause d'un gain : un autre gagnant de la même boule partage le prix
    const prize = this.phase === 'win' ? PRIZES.find((x) => x.id === last.prize) : this.prize;
    if (!prize || (this.phase !== 'draw' && this.phase !== 'win')) return;
    const ok = this.cards.get(p.pid).some((g) => fullLines(g, this.drawnSet) >= prize.lines);
    if (!ok) {
      this.lock.set(p.pid, Date.now() + LOTO.lockMs);
      this.note('wrong', { pid: p.pid, prize: prize.id });
      return this.changed();
    }
    if (this.phase === 'win') {
      if (last.at !== this.drawn.length) return;
      this.addWinner(last, p.pid);
      this.note('win', { prize: prize.id, pids: last.pids });
      return this.changed();
    }
    this.win([p.pid]);
  }

  end() {
    if (this.phase === 'podium') return;
    this.podium(LOTO.podiumMs);
  }

  onMessage(p, m) {
    if (m.t === 'loto_claim') return this.claim(p);
    if (m.t === 'loto_mark') {
      const marks = this.marks.get(p.pid);
      if (!marks || this.auto || !Number.isInteger(m.n)) return;
      if (!this.cards.get(p.pid).some((g) => g.some((row) => row.includes(m.n)))) return;
      if (marks.has(m.n)) marks.delete(m.n); else marks.add(m.n);
      return this.changed();
    }
    this.hostCommand(p, m, () => {
      // « Suivant » : boule suivante tout de suite
      if (this.phase === 'intro' || this.phase === 'draw') this.draw();
      else if (this.phase === 'win') this.afterWin();
    });
  }

  hostCommand(p, m, next) {
    if (m.t === 'game_end' && p.pid === this.room.hostPid && this.phase !== 'podium') { this.end(); return true; }
    return super.hostCommand(p, m, next);
  }

  publicState() {
    const prize = this.prize;
    // Qui s'approche du prochain prix (calculé avec les boules tirées, pas les marques)
    const near = [];
    if (prize && this.phase === 'draw') {
      for (const [pid, gs] of this.cards) {
        if (!this.room.players.has(pid)) continue;
        const miss = Math.min(...gs.map((g) => missingFor(g, this.drawnSet, prize.lines)));
        if (miss > 0 && miss <= 2) near.push({ pid, miss });
      }
      near.sort((a, b) => a.miss - b.miss);
    }
    return {
      ...this.base('loto'),
      seq: this.seq,
      index: this.drawn.length,       // pour l'animateur : une annonce par boule
      drawn: this.drawn,
      last: this.drawn[this.drawn.length - 1] ?? null,
      nick: NICKNAMES[this.drawn[this.drawn.length - 1]] ?? null,
      prize: prize ? { id: prize.id, title: prize.title, points: prize.points } : null,
      auto: this.auto,
      winners: this.winners.map((w) => ({ prize: w.prize, title: w.title, pids: w.pids })),
      near: near.slice(0, 6),
      event: this.event,
    };
  }

  playerState(pid) {
    const r = this.ranking().find((x) => x.pid === pid);
    return {
      cards: this.cards.get(pid) ?? [],
      marks: [...(this.marks.get(pid) ?? [])],
      lockedFor: Math.max(0, (this.lock.get(pid) || 0) - Date.now()),
      score: r?.score ?? 0,
      rank: r?.rank ?? null,
      players: this.ranking().length,
    };
  }
}
