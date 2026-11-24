// Chiffres et lettres : manches « Le mot le plus long » et « Le compte est bon », comme à la télé.
// Lettres : un joueur (à tour de rôle) tire 9 lettres en choisissant voyelle ou consonne, puis
// chacun compose le plus long mot possible sur son téléphone (dictionnaire du Scrabroc).
// Chiffres : un nombre de 101 à 999 et 6 plaques ; chacun fait ses calculs sur son téléphone,
// le serveur rejoue chaque calcul et garde le meilleur résultat (le plus proche).
// Rien de ce qu'un joueur a trouvé n'est public avant la révélation (seulement qui a fini / trouvé pile).
import crypto from 'node:crypto';
import { BaseGame, fastTimings, fold, shuffle } from './common.js';
import { dict } from './scrabroc.js';

export const CEL = fastTimings({
  rounds: [4, 6, 8],
  defaultRounds: 6,
  modes: ['Lettres et chiffres', 'Lettres seulement', 'Chiffres seulement'],
  times: ['30 s', '45 s', '60 s'],
  defaultTime: '45 s',
  introMs: 7000,
  pickMs: 5000,        // pour choisir voyelle / consonne, sinon tiré tout seul
  autoPickMs: 450,     // tirage tout seul (tireur parti)
  readyMs: 1500,       // les 9 lettres sont là, on souffle avant le chrono
  revealMs: 10000,
  podiumMs: 25000,
  letterPoints: 50,    // par lettre du mot
  longestBonus: 100,   // le (ou les) plus long(s)
  exactPoints: 500,
  speedPoints: 200,
  nearPoints: [[5, 300], [10, 150], [25, 50]], // écart max → points
});

export const LETTERS = 9;
export const VOWELS = { A: 9, E: 12, I: 8, O: 6, U: 6, Y: 1 };
export const CONSONANTS = { B: 2, C: 4, D: 4, F: 2, G: 2, H: 2, J: 1, K: 0.4, L: 5, M: 3, N: 7, P: 3, Q: 1, R: 7, S: 7, T: 7, V: 2, W: 0.3, X: 0.5, Z: 0.5 };
const MIN_V = 2, MIN_C = 3, MAX_SAME = 3;

const isVowel = (l) => l in VOWELS;

function weighted(table, drawn) {
  const entries = Object.entries(table).filter(([l]) => drawn.filter((x) => x === l).length < MAX_SAME);
  const total = entries.reduce((s, [, w]) => s + w, 0);
  let r = Math.random() * total;
  for (const [l, w] of entries) { r -= w; if (r <= 0) return l; }
  return entries.at(-1)[0];
}

// Voyelle ou consonne imposée quand il ne reste plus que de quoi tenir les minimums
export function forcedKind(drawn) {
  const v = drawn.filter(isVowel).length, c = drawn.length - v, left = LETTERS - drawn.length;
  if (MIN_V - v >= left) return 'v';
  if (MIN_C - c >= left) return 'c';
  return null;
}

export function drawLetter(drawn, kind) {
  const k = forcedKind(drawn) ?? kind;
  return weighted(k === 'v' ? VOWELS : CONSONANTS, drawn);
}

// Le mot peut-il s'écrire avec ces lettres (chacune une fois) ?
export function fits(word, letters) {
  const left = [...letters];
  for (const ch of word) {
    const i = left.indexOf(ch);
    if (i < 0) return false;
    left.splice(i, 1);
  }
  return true;
}

// Les plus longs mots possibles (jusqu'à n), longueur décroissante
let SHORT = null; // mots de 9 lettres au plus, avec le nombre de chaque lettre
export function longestWords(letters, n = 3) {
  SHORT ??= [...dict()].filter((w) => w.length <= LETTERS).map((w) => [w, counts(w)]);
  const have = counts(letters.join(''));
  const out = [];
  for (const [w, c] of SHORT) {
    if (w.length > letters.length) continue;
    let ok = true;
    for (let i = 0; i < 26; i++) if (c[i] > have[i]) { ok = false; break; }
    if (ok) out.push(w);
  }
  out.sort((a, b) => b.length - a.length || a.localeCompare(b));
  return out.slice(0, n);
}

function counts(w) {
  const c = new Uint8Array(26);
  for (let i = 0; i < w.length; i++) c[w.charCodeAt(i) - 65]++;
  return c;
}

// ---------------------------------------------------------------- chiffres
export const OPS = ['+', '-', '*', '/'];
const PLATES = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 25, 50, 75, 100];

export function applyOp(a, op, b) {
  if (op === '+') return a + b;
  if (op === '*') return a * b;
  if (op === '-') return a > b ? a - b : null;
  if (op === '/') return b > 1 && a % b === 0 ? a / b : null;
  return null;
}

// Rejoue des calculs [[a, op, b], …] avec les plaques : chaque nombre doit être disponible
// (plaque ou résultat d'avant), et n'est utilisé qu'une fois. null si un calcul est faux.
export function replay(plates, steps) {
  if (!Array.isArray(steps) || steps.length > 5) return null;
  const pool = [...plates];
  const done = [];
  for (const s of steps) {
    if (!Array.isArray(s) || s.length !== 3) return null;
    const [a, op, b] = s;
    if (!Number.isInteger(a) || !Number.isInteger(b) || !OPS.includes(op)) return null;
    const ia = pool.indexOf(a);
    if (ia < 0) return null;
    pool.splice(ia, 1);
    const ib = pool.indexOf(b);
    if (ib < 0) return null;
    pool.splice(ib, 1);
    const r = applyOp(a, op, b);
    if (r === null) return null;
    pool.push(r);
    done.push([a, op, b, r]);
  }
  return { pool, steps: done };
}

// Meilleure solution (exacte si possible) : recherche complète, coupée dès qu'on trouve pile
export function solve(plates, target) {
  let best = { d: Infinity, v: null, steps: [] };
  const seen = new Set();
  const rec = (nums, steps) => {
    for (const v of nums) {
      const d = Math.abs(v - target);
      if (d < best.d || (d === best.d && steps.length < best.steps.length)) best = { d, v, steps: [...steps] };
    }
    if (best.d === 0 || nums.length < 2) return;
    const key = [...nums].sort((x, y) => x - y).join(',');
    if (seen.has(key)) return;
    seen.add(key);
    for (let i = 0; i < nums.length; i++) {
      for (let j = 0; j < nums.length; j++) {
        if (i === j) continue;
        const a = nums[i], b = nums[j];
        const rest = nums.filter((_, k) => k !== i && k !== j);
        for (const op of OPS) {
          if ((op === '+' || op === '*') && i > j) continue; // a op b = b op a
          if (op === '*' && (a === 1 || b === 1)) continue;
          const r = applyOp(a, op, b);
          if (r === null || r === b) continue;
          steps.push([a, op, b, r]);
          rec([...rest, r], steps);
          steps.pop();
          if (best.d === 0) return;
        }
      }
    }
  };
  rec(plates, []);
  // Une solution exacte n'utilise que les calculs utiles (on retire ceux qui ne servent à rien)
  return { ...best, steps: usefulSteps(best.steps, best.v) };
}

function usefulSteps(steps, v) {
  const need = [v];
  const keep = [];
  for (let i = steps.length - 1; i >= 0; i--) {
    const [a, , b, r] = steps[i];
    const k = need.indexOf(r);
    if (k < 0) continue;
    need.splice(k, 1);
    need.push(a, b);
    keep.unshift(steps[i]);
  }
  return keep;
}

// Un tirage qui a une solution exacte
export function drawNumbers() {
  for (let tries = 0; tries < 60; tries++) {
    const bag = shuffle([...PLATES]);
    const big = crypto.randomInt(0, 3); // 0 à 2 grandes plaques, comme souvent à la télé
    const bigs = bag.filter((x) => x >= 25).slice(0, big);
    const smalls = bag.filter((x) => x <= 10).slice(0, 6 - big);
    const plates = shuffle([...bigs, ...smalls]);
    const target = crypto.randomInt(101, 1000);
    const s = solve(plates, target);
    if (s.d === 0) return { plates, target, solution: s.steps };
  }
  return { plates: [25, 50, 6, 3, 7, 1], target: 712, solution: solve([25, 50, 6, 3, 7, 1], 712).steps };
}

export function nearPoints(d) {
  for (const [max, pts] of CEL.nearPoints) if (d <= max) return pts;
  return 0;
}

const secs = (v) => fastTimings({ durMs: parseInt(CEL.times.includes(v) ? v : CEL.defaultTime, 10) * 1000 }).durMs;

export class ChiffresGame extends BaseGame {
  static id = 'chiffres';

  static async create(room, opts, hooks) {
    dict(); // chargé une fois (Scrabroc)
    return new ChiffresGame(room, hooks, opts);
  }

  constructor(room, hooks, opts) {
    super(room, hooks);
    this.podiumMs = CEL.podiumMs;
    this.count = CEL.rounds.includes(opts?.rounds) ? opts.rounds : CEL.defaultRounds;
    const mode = CEL.modes.includes(opts?.mode) ? opts.mode : CEL.modes[0];
    this.kinds = Array.from({ length: this.count }, (_, i) => (mode === CEL.modes[1] ? 'L' : mode === CEL.modes[2] ? 'C' : i % 2 ? 'C' : 'L'));
    this.thinkMs = secs(opts?.temps);
    this.index = -1;
    this.drawers = 0;
    this.round = null;
    this.answers = new Map(); // pid -> lettres { w, at } | chiffres { v, d, steps, at }
  }

  start() { this.schedule(CEL.introMs, () => this.next()); }

  next() {
    this.index++;
    if (this.index >= this.count) return this.podium(CEL.podiumMs);
    this.answers.clear();
    this.gains.clear();
    if (this.kinds[this.index] === 'L') {
      const act = this.active();
      const drawer = act.length ? act[this.drawers++ % act.length].pid : null;
      this.round = { kind: 'L', letters: [], drawer, best: null };
      this.phase = 'draw';
      this.waitPick();
    } else {
      this.round = { kind: 'C', ...drawNumbers() };
      this.think();
    }
  }

  // Le tireur a pickMs pour choisir, sinon tirage tout seul (plus vite s'il n'est plus là)
  waitPick() {
    const here = this.room.players.get(this.round.drawer)?.connected;
    this.schedule(here ? CEL.pickMs : CEL.autoPickMs, () => this.pick(Math.random() < 0.42 ? 'v' : 'c'));
    this.changed();
  }

  pick(kind) {
    if (this.phase !== 'draw') return;
    const r = this.round;
    r.letters.push(drawLetter(r.letters, kind));
    if (r.letters.length < LETTERS) return this.waitPick();
    this.phase = 'ready';
    r.best = longestWords(r.letters);
    this.schedule(CEL.readyMs, () => this.think());
    this.changed();
  }

  think() {
    this.phase = 'think';
    this.thinkStart = Date.now();
    this.schedule(this.thinkMs, () => this.reveal());
    this.changed();
  }

  // Fin avant le chrono : tout le monde a trouvé le mieux possible
  checkAll() {
    const act = this.active();
    if (!act.length || this.phase !== 'think') return;
    const r = this.round;
    const top = r.kind === 'L' ? (r.best[0]?.length ?? 0) : 0;
    const done = (pid) => {
      const a = this.answers.get(pid);
      return a && (r.kind === 'L' ? a.w.length >= top : a.d === 0);
    };
    if (act.every((p) => done(p.pid))) this.schedule(700, () => this.reveal());
  }

  reveal() {
    if (this.phase !== 'think') return;
    this.phase = 'reveal';
    const r = this.round;
    if (r.kind === 'L') {
      const longest = Math.max(0, ...[...this.answers.values()].map((a) => a.w.length));
      for (const [pid, a] of this.answers) this.addPoints(pid, a.w.length * CEL.letterPoints + (a.w.length === longest ? CEL.longestBonus : 0));
    } else {
      for (const [pid, a] of this.answers) {
        const speed = Math.max(0, 1 - (a.at - this.thinkStart) / this.thinkMs);
        this.addPoints(pid, a.d === 0 ? CEL.exactPoints + Math.round((CEL.speedPoints * speed) / 10) * 10 : nearPoints(a.d));
      }
    }
    this.schedule(CEL.revealMs, () => (this.index >= this.count - 1 ? this.podium(CEL.podiumMs) : this.next()));
    this.changed();
  }

  onMessage(p, m) {
    const r = this.round;
    if (m.t === 'cel_pick') {
      if (this.phase === 'draw' && p.pid === r.drawer && (m.k === 'v' || m.k === 'c')) this.pick(m.k);
      return;
    }
    if (m.t === 'cel_word') {
      if (this.phase !== 'think' || r.kind !== 'L' || m.r !== this.index) return;
      const w = fold(String(m.w || '')).toUpperCase().replace(/[^A-Z]/g, '');
      let err = null;
      if (w.length < 2) err = 'Trop court';
      else if (!fits(w, r.letters)) err = 'Pas avec ces lettres';
      else if (!dict().has(w)) err = 'Pas dans le dictionnaire';
      const prev = this.answers.get(p.pid);
      const kept = !err && (!prev || w.length > prev.w.length);
      if (kept) this.answers.set(p.pid, { w, at: Date.now() });
      this.hooks.sendTo(p.pid, { t: 'cel_word_res', r: this.index, w, ok: !err, err, kept, best: this.answers.get(p.pid)?.w ?? null });
      if (kept) { this.onPlayerJoin(p); this.checkAll(); this.changed(); }
      return;
    }
    if (m.t === 'cel_calc') {
      if (this.phase !== 'think' || r.kind !== 'C' || m.r !== this.index) return;
      const res = replay(r.plates, m.steps);
      if (!res) return;
      let v = null;
      for (const x of res.pool) if (v === null || Math.abs(x - r.target) < Math.abs(v - r.target)) v = x;
      const d = Math.abs(v - r.target);
      const prev = this.answers.get(p.pid);
      if (prev && prev.d <= d) return;
      this.answers.set(p.pid, { v, d, steps: res.steps, at: Date.now() });
      this.onPlayerJoin(p);
      this.checkAll();
      this.changed();
      return;
    }
    this.hostCommand(p, m, () => {
      if (this.phase === 'intro' || this.phase === 'reveal') (this.phase === 'reveal' && this.index >= this.count - 1 ? this.podium(CEL.podiumMs) : this.next());
      else if (this.phase === 'draw') { while (this.phase === 'draw') this.pick(forcedKind(r.letters) ?? (Math.random() < 0.42 ? 'v' : 'c')); }
      else if (this.phase === 'ready') this.think();
      else if (this.phase === 'think') this.reveal();
    });
  }

  onPlayerGone(p) {
    if (this.phase === 'draw' && p?.pid === this.round.drawer) this.waitPick();
    this.checkAll();
  }

  publicState() {
    const s = { ...this.base('chiffres'), index: this.index, count: this.count };
    const r = this.round;
    if (!r || this.phase === 'intro' || this.phase === 'podium') return s;
    s.kind = r.kind;
    if (r.kind === 'L') {
      Object.assign(s, { letters: r.letters, drawer: r.drawer, forced: this.phase === 'draw' ? forcedKind(r.letters) : null });
      if (this.phase === 'think') s.answered = [...this.answers.keys()];
      if (this.phase === 'reveal') {
        s.words = [...this.answers].map(([pid, a]) => ({ pid, w: a.w })).sort((x, y) => y.w.length - x.w.length);
        s.best = r.best;
      }
    } else {
      Object.assign(s, { plates: r.plates, target: r.target });
      if (this.phase === 'think') s.exact = [...this.answers].filter(([, a]) => a.d === 0).map(([pid]) => pid);
      if (this.phase === 'reveal') {
        s.results = [...this.answers]
          .map(([pid, a]) => ({ pid, v: a.v, d: a.d, ms: a.at - this.thinkStart }))
          .sort((x, y) => x.d - y.d || x.ms - y.ms);
        // La solution du plus rapide qui a trouvé pile, sinon celle du jeu
        const first = s.results.find((x) => x.d === 0);
        s.solution = first ? this.answers.get(first.pid).steps : r.solution;
        s.solutionBy = first?.pid ?? null;
      }
    }
    return s;
  }

  playerState(pid) {
    const rk = this.ranking().find((x) => x.pid === pid);
    const a = this.answers.get(pid);
    return {
      gain: this.phase === 'reveal' ? (this.gains.get(pid) || 0) : null,
      score: rk?.score ?? 0,
      rank: rk?.rank ?? null,
      players: this.ranking().length,
      word: this.round?.kind === 'L' ? (a?.w ?? null) : null,
      calc: this.round?.kind === 'C' && a ? { v: a.v, d: a.d } : null,
    };
  }
}
