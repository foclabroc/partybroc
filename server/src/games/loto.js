// Loto : la TV tire les boules (1 à 90), chacun a son carton (ou 2) sur son téléphone.
// Carton français : 3 lignes × 9 colonnes, 15 numéros, 5 par ligne ; colonne 1 : 1-9,
// colonne 2 : 10-19 … colonne 9 : 80-90 ; les cases vides sont vertes.
// Les cartons forment une série fixe de 300 (le n° 17 est toujours le même carton, « 017/300»).
// Au début, chacun choisit son ou ses cartons parmi au moins 20 cartons tirés de la série
// (pas deux joueurs sur le même carton ; à la fin du temps, ceux qui manquent sont donnés au hasard).
// On joue « Une ligne », puis « Deux lignes », puis « Carton plein ».
// Marquage « À la main » : on touche ses numéros et on annonce soi-même (le serveur vérifie avec
// les boules tirées ; faux = 5 s sans pouvoir réannoncer). « Automatique » : tout est marqué et
// annoncé par le serveur. Plusieurs gagnants pour la même boule = gain partagé (chacun a tous
// les points).
import crypto from 'node:crypto';
import { BaseGame, fastTimings, shuffle } from './common.js';

export const LOTO = fastTimings({
  cartons: [1, 2],
  defaultCartons: 1,
  speeds: ['Lente', 'Normale', 'Rapide'],
  defaultSpeed: 'Normale',
  marks: ['À la main', 'Automatique'],
  defaultMarks: 'À la main',
  pool: 20,               // cartons proposés au choix (plus s'il y a beaucoup de joueurs)
  introMs: 6000,
  chooseMs: 45000,        // temps pour choisir ses cartons
  readyMs: 2500,          // tout le monde a choisi : petite pause avant la 1re boule
  winMs: 6000,            // pause sur le gain (les autres gagnants de la même boule y entrent aussi)
  lockMs: 5000,           // fausse annonce
  podiumMs: 25000,
});
const SPEED_MS = { Lente: 9000, Normale: 6000, Rapide: 4000 };
export const PRIZES = [
  { id: 'ligne', title: 'Une ligne', lines: 1, points: 300 },
  { id: 'deux', title: 'Deux lignes', lines: 2, points: 500 },
  { id: 'plein', title: 'Carton plein', lines: 3, points: 1000 },
];
// Quelques surnoms du loto, lus par l'animateur et écrits sous la boule
export const NICKNAMES = { 1: 'le petit', 22: 'les deux canards', 33: 'l’âge du Christ', 90: 'le grand-père' };

// ------------------------------------------------------------------ série de cartons

export const SERIES = 300;

// Générateur pseudo-aléatoire à graine (le même carton à chaque fois pour un numéro donné)
function seeded(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function shuffleWith(rand, arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

// Un carton : rows[3][9], 0 = case vide. rand : générateur (aléatoire par défaut)
export function makeCarton(rand = () => crypto.randomInt(1 << 30) / (1 << 30)) {
  for (let attempt = 0; attempt < 500; attempt++) {
    // combien de numéros par colonne (1 à 3, 15 en tout)
    const count = Array(9).fill(1);
    let left = 6;
    while (left > 0) {
      const c = Math.floor(rand() * 9);
      if (count[c] < 3) { count[c]++; left--; }
    }
    // dans quelles lignes : chaque ligne doit avoir 5 numéros
    const rows = [[], [], []];
    const grid = [Array(9).fill(0), Array(9).fill(0), Array(9).fill(0)];
    const perRow = [0, 0, 0];
    let ok = true;
    // colonnes à 3 d'abord, puis à 2, puis à 1 : on remplit les lignes les moins pleines
    const order = shuffleWith(rand, [...Array(9).keys()]).sort((a, b) => count[b] - count[a]);
    for (const c of order) {
      const pick = shuffleWith(rand, [0, 1, 2]).sort((a, b) => perRow[a] - perRow[b]).slice(0, count[c]);
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
      const nums = shuffleWith(rand, Array.from({ length: hi - lo + 1 }, (_, i) => lo + i)).slice(0, count[c]).sort((a, b) => a - b);
      const rs = [0, 1, 2].filter((r) => rows[r].includes(c));
      rs.forEach((r, i) => { grid[r][c] = nums[i]; });
    }
    return grid;
  }
  throw new Error('carton impossible');
}

// La série : 300 cartons tous différents, toujours les mêmes
export const CARTONS = (() => {
  const seen = new Set();
  const list = [];
  let seed = 1;
  while (list.length < SERIES) {
    const g = makeCarton(seeded(20261104 + seed++));
    const key = JSON.stringify(g);
    if (seen.has(key)) continue;
    seen.add(key);
    list.push(g);
  }
  return list;
})();
export const cartonOf = (no) => CARTONS[no - 1];

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
    this.perPlayer = LOTO.cartons.includes(opts.cartons) ? opts.cartons : LOTO.defaultCartons;
    this.speed = SPEED_MS[opts.vitesse] ?? SPEED_MS[LOTO.defaultSpeed];
    if (process.env.PB_FAST) this.speed = Math.round(this.speed / 10);
    this.auto = opts.marquage === 'Automatique';
    this.bag = shuffle(Array.from({ length: 90 }, (_, i) => i + 1));
    this.drawn = [];
    this.drawnSet = new Set();
    // Cartons proposés : au moins 20, et toujours 5 de plus que ce qu'il faut
    const need = this.active().length * this.perPlayer;
    const size = Math.min(SERIES, Math.max(LOTO.pool, need + 5));
    this.pool = shuffle(Array.from({ length: SERIES }, (_, i) => i + 1)).slice(0, size).sort((a, b) => a - b);
    this.taken = new Map();   // n° de carton -> pid
    this.mine = new Map();    // pid -> [n° de carton]
    this.marks = new Map();
    for (const p of this.active()) {
      this.mine.set(p.pid, []);
      this.marks.set(p.pid, new Set());
    }
    this.stage = 0;            // prix en jeu : PRIZES[stage]
    this.winners = [];         // { prize, title, pids, at }
    this.lock = new Map();     // pid -> fin du blocage (fausse annonce)
    this.event = null;
    this.seq = 0;
  }

  get prize() { return PRIZES[this.stage] ?? null; }
  grids(pid) { return (this.mine.get(pid) ?? []).map(cartonOf); }
  playing() { return [...this.mine.keys()].filter((pid) => this.room.players.has(pid) && this.mine.get(pid).length); }

  start() {
    this.schedule(LOTO.introMs, () => this.choose());
  }

  note(k, extra = {}) { this.event = { seq: ++this.seq, k, ...extra }; }

  // ---------------------------------------------------------------- choix des cartons

  choose() {
    this.phase = 'choose';
    this.chooseEnd = Date.now() + LOTO.chooseMs;
    this.schedule(LOTO.chooseMs, () => this.chosen());
    this.changed();
  }

  pick(p, no) {
    if (this.phase !== 'choose' || !Number.isInteger(no) || !this.pool.includes(no)) return;
    let mine = this.mine.get(p.pid);
    if (!mine) {
      // arrivé pendant le choix : il joue aussi
      mine = [];
      this.mine.set(p.pid, mine);
      this.marks.set(p.pid, new Set());
    }
    const owner = this.taken.get(no);
    if (owner === p.pid) {
      // le rendre
      this.taken.delete(no);
      mine.splice(mine.indexOf(no), 1);
    } else if (owner) {
      return;
    } else {
      // déjà assez de cartons : on échange le plus ancien
      if (mine.length >= this.perPlayer) this.taken.delete(mine.shift());
      mine.push(no);
      this.taken.set(no, p.pid);
    }
    this.changed();
    // Tout le monde a ses cartons : on commence
    const all = this.active().every((pl) => (this.mine.get(pl.pid)?.length ?? 0) >= this.perPlayer);
    if (all) this.schedule(LOTO.readyMs, () => this.chosen());
    else this.schedule(Math.max(0, this.chooseEnd - Date.now()), () => this.chosen());
  }

  // Fin du choix : ceux qui n'ont pas fini reçoivent des cartons libres au hasard
  chosen() {
    if (this.phase !== 'choose') return;
    const free = shuffle(this.pool.filter((no) => !this.taken.has(no)));
    for (const p of this.active()) {
      let mine = this.mine.get(p.pid);
      if (!mine) {
        mine = [];
        this.mine.set(p.pid, mine);
        this.marks.set(p.pid, new Set());
      }
      while (mine.length < this.perPlayer && free.length) {
        const no = free.pop();
        mine.push(no);
        this.taken.set(no, p.pid);
      }
    }
    this.draw();
  }

  // ---------------------------------------------------------------- tirage

  draw() {
    if (this.over) return;
    const n = this.bag.pop();
    if (n === undefined) return this.end();
    this.drawn.push(n);
    this.drawnSet.add(n);
    this.phase = 'draw';
    if (this.auto) {
      for (const pid of this.mine.keys()) if (this.grids(pid).some((g) => g.some((row) => row.includes(n)))) this.marks.get(pid).add(n);
      if (this.autoWin()) return;
    }
    this.schedule(this.speed, () => this.draw());
    this.changed();
  }

  // Marquage automatique : le serveur annonce lui-même les gagnants
  autoWin() {
    const won = this.playing().filter((pid) => this.grids(pid).some((g) => fullLines(g, this.drawnSet) >= this.prize.lines));
    if (!won.length) return false;
    this.win(won);
    return true;
  }

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
    if (this.auto || !this.grids(p.pid).length) return;
    if ((this.lock.get(p.pid) || 0) > Date.now()) return;
    const last = this.winners[this.winners.length - 1];
    // Pendant la pause d'un gain : un autre gagnant de la même boule partage le prix
    const prize = this.phase === 'win' ? PRIZES.find((x) => x.id === last.prize) : this.prize;
    if (!prize || (this.phase !== 'draw' && this.phase !== 'win')) return;
    const ok = this.grids(p.pid).some((g) => fullLines(g, this.drawnSet) >= prize.lines);
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
    if (m.t === 'loto_pick') return this.pick(p, m.no);
    if (m.t === 'loto_claim') return this.claim(p);
    if (m.t === 'loto_mark') {
      const marks = this.marks.get(p.pid);
      if (!marks || this.auto || !Number.isInteger(m.n)) return;
      if (!this.grids(p.pid).some((g) => g.some((row) => row.includes(m.n)))) return;
      if (marks.has(m.n)) marks.delete(m.n); else marks.add(m.n);
      return this.changed();
    }
    this.hostCommand(p, m, () => {
      // « Suivant » : fin du choix, ou boule suivante tout de suite
      if (this.phase === 'intro') this.choose();
      else if (this.phase === 'choose') this.chosen();
      else if (this.phase === 'draw') this.draw();
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
      for (const pid of this.playing()) {
        const miss = Math.min(...this.grids(pid).map((g) => missingFor(g, this.drawnSet, prize.lines)));
        if (miss > 0 && miss <= 2) near.push({ pid, miss });
      }
      near.sort((a, b) => a.miss - b.miss);
    }
    const s = {
      ...this.base('loto'),
      seq: this.seq,
      index: this.drawn.length,       // pour l'animateur : une annonce par boule
      series: SERIES,
      perPlayer: this.perPlayer,
      drawn: this.drawn,
      last: this.drawn[this.drawn.length - 1] ?? null,
      nick: NICKNAMES[this.drawn[this.drawn.length - 1]] ?? null,
      prize: prize ? { id: prize.id, title: prize.title, points: prize.points } : null,
      auto: this.auto,
      winners: this.winners.map((w) => ({ prize: w.prize, title: w.title, pids: w.pids })),
      near: near.slice(0, 6),
      event: this.event,
    };
    // Pendant le choix : les cartons proposés (pas secrets : personne ne les a encore)
    if (this.phase === 'choose' || this.phase === 'intro') {
      s.pool = this.pool.map((no) => ({ no, grid: cartonOf(no), by: this.taken.get(no) ?? null }));
      s.picked = [...this.mine].map(([pid, nos]) => ({ pid, n: nos.length }));
    }
    return s;
  }

  playerState(pid) {
    const r = this.ranking().find((x) => x.pid === pid);
    return {
      cards: (this.mine.get(pid) ?? []).map((no) => ({ no, grid: cartonOf(no) })),
      marks: [...(this.marks.get(pid) ?? [])],
      lockedFor: Math.max(0, (this.lock.get(pid) || 0) - Date.now()),
      score: r?.score ?? 0,
      rank: r?.rank ?? null,
      players: this.ranking().length,
    };
  }
}
