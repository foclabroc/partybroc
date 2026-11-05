// Scrabroc : jeu de lettres sur un plateau 15 × 15 (nom et visuels à nous).
// 102 jetons (répartition et valeurs françaises, 2 jokers), 2 sacs au-delà de 4 joueurs.
// Chevalet de 7 lettres. Le premier mot passe par le centre ; ensuite chaque coup touche un mot
// posé ; les lettres d'un coup sont sur une ligne ou une colonne, sans trou. Cases L×2 / L×3
// (la lettre), M×2 / M×3 (le mot), seulement au tour où on les recouvre ; 7 lettres d'un coup : +50.
// Tous les mots formés doivent être dans le dictionnaire (server/data/mots.txt.gz,
// tools/mots_scrabroc.py) : sinon le coup est refusé et le joueur réessaie.
// Fin : sac vide et un chevalet vide (il gagne la valeur des lettres des autres, qui la perdent),
// ou trop de tours passés d'affilée. Points de la partie = score final (au moins 0).
import fs from 'node:fs';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';
import { BaseGame, botMs, fastTimings, shuffle } from './common.js';

export const SCR = fastTimings({
  introMs: 10000,
  goneMs: 4000,
  podiumMs: 30000,
  times: ['1 min', '2 min', '3 min'],
  defaultTime: '2 min',
});

export const VAL = { A: 1, B: 3, C: 3, D: 2, E: 1, F: 4, G: 2, H: 4, I: 1, J: 8, K: 10, L: 1, M: 2, N: 1, O: 1, P: 3, Q: 8, R: 1, S: 1, T: 1, U: 1, V: 4, W: 10, X: 10, Y: 10, Z: 10, '?': 0 };
const COUNT = { A: 9, B: 2, C: 2, D: 3, E: 15, F: 2, G: 2, H: 2, I: 8, J: 1, K: 1, L: 5, M: 3, N: 6, O: 6, P: 2, Q: 1, R: 6, S: 6, T: 6, U: 6, V: 2, W: 1, X: 1, Y: 1, Z: 1, '?': 2 };

// Cases bonus : un huitième du plateau, recopié par symétrie
export const BONUS = {};
const sym = (kind, cells) => {
  for (const [r, c] of cells) {
    for (const [a, b] of [[r, c], [c, r], [14 - r, c], [r, 14 - c], [14 - r, 14 - c], [c, 14 - r], [14 - c, r], [14 - c, 14 - r]]) BONUS[`${a},${b}`] = kind;
  }
};
sym('l2', [[0, 3], [2, 6], [3, 7], [6, 6]]);
sym('l3', [[1, 5], [5, 5]]);
sym('w2', [[1, 1], [2, 2], [3, 3], [4, 4]]);
sym('w3', [[0, 0], [0, 7]]);
BONUS['7,7'] = 'star';

// ---------------------------------------------------------------- dictionnaire
let DICT = null;
let BOT_WORDS = null;
export function dict() {
  if (!DICT) {
    try {
      const file = fileURLToPath(new URL('../../data/mots.txt.gz', import.meta.url));
      DICT = new Set(zlib.gunzipSync(fs.readFileSync(file)).toString('ascii').split('\n').filter(Boolean));
    } catch (e) {
      console.error('[scrabroc] dictionnaire introuvable', e.message);
      DICT = new Set();
    }
    BOT_WORDS = [...DICT].filter((w) => w.length <= 8);
  }
  return DICT;
}

export function makeBag(players) {
  const bag = [];
  const sets = players > 4 ? 2 : 1;
  for (let s = 0; s < sets; s++) for (const [l, n] of Object.entries(COUNT)) for (let i = 0; i < n; i++) bag.push(l);
  return shuffle(bag);
}

// ---------------------------------------------------------------- règles d'un coup
// placed : [{ r, c, l, j }] (j = joker). Renvoie { ok, err, words: [{ w, s }], total, bingo }.
export function evaluate(board, placed, words = dict()) {
  if (!placed.length) return { ok: false, err: 'Pose au moins une lettre' };
  const at = (r, c) => (r >= 0 && r < 15 && c >= 0 && c < 15 ? board[r][c] : undefined);
  const g = new Map(placed.map((p) => [`${p.r},${p.c}`, p]));
  if (g.size !== placed.length) return { ok: false, err: 'Deux lettres sur la même case' };
  const get = (r, c) => g.get(`${r},${c}`) || at(r, c);
  for (const p of placed) {
    if (!(p.r >= 0 && p.r < 15 && p.c >= 0 && p.c < 15)) return { ok: false, err: 'Hors du plateau' };
    if (at(p.r, p.c)) return { ok: false, err: 'Case déjà prise' };
  }
  const rows = new Set(placed.map((p) => p.r));
  const cols = new Set(placed.map((p) => p.c));
  if (rows.size > 1 && cols.size > 1) return { ok: false, err: 'Les lettres doivent être sur une même ligne ou colonne' };
  const first = board.every((row) => row.every((x) => !x));
  if (first && !g.has('7,7')) return { ok: false, err: 'Le premier mot passe par l’étoile' };
  if (first && placed.length < 2) return { ok: false, err: 'Il faut au moins 2 lettres' };
  const p0 = placed[0];
  let horiz = rows.size === 1 && (cols.size > 1 || !!(get(p0.r, p0.c - 1) || get(p0.r, p0.c + 1)));
  if (placed.length === 1 && !horiz && !(get(p0.r - 1, p0.c) || get(p0.r + 1, p0.c))) return { ok: false, err: 'La lettre doit toucher un mot' };
  const dr = horiz ? 0 : 1;
  const dc = horiz ? 1 : 0;
  const sorted = [...placed].sort((a, b) => (horiz ? a.c - b.c : a.r - b.r));
  const end = sorted[sorted.length - 1];
  for (let r = sorted[0].r, c = sorted[0].c; r <= end.r && c <= end.c; r += dr, c += dc) {
    if (!get(r, c)) return { ok: false, err: 'Pas de trou entre les lettres' };
  }
  const line = (r, c, dr2, dc2) => {
    while (get(r - dr2, c - dc2)) { r -= dr2; c -= dc2; }
    const cells = [];
    while (get(r, c)) { cells.push({ r, c, t: get(r, c), nw: g.has(`${r},${c}`) }); r += dr2; c += dc2; }
    return cells;
  };
  const found = [];
  const main = line(sorted[0].r, sorted[0].c, dr, dc);
  if (main.length > 1) found.push(main);
  for (const p of placed) {
    const w = line(p.r, p.c, dc, dr);
    if (w.length > 1) found.push(w);
  }
  if (!found.length) return { ok: false, err: 'Il faut au moins 2 lettres' };
  if (!first && !found.some((w) => w.some((x) => !x.nw))) return { ok: false, err: 'Le mot doit toucher un mot déjà posé' };
  let total = 0;
  const out = [];
  const bad = [];
  for (const w of found) {
    const txt = w.map((x) => x.t.l).join('');
    let s = 0;
    let m = 1;
    for (const x of w) {
      let v = x.t.j ? 0 : VAL[x.t.l];
      if (x.nw) {
        const b = BONUS[`${x.r},${x.c}`];
        if (b === 'l2') v *= 2;
        if (b === 'l3') v *= 3;
        if (b === 'w2' || b === 'star') m *= 2;
        if (b === 'w3') m *= 3;
      }
      s += v;
    }
    s *= m;
    total += s;
    out.push({ w: txt, s });
    if (!words.has(txt)) bad.push(txt);
  }
  const bingo = placed.length === 7;
  if (bingo) total += 50;
  if (bad.length) return { ok: false, err: `${bad.join(', ')} : mot inconnu`, words: out, total, bingo };
  return { ok: true, words: out, total, bingo };
}

export class ScrabrocGame extends BaseGame {
  static id = 'scrabroc';

  static async create(room, opts, hooks) {
    dict();
    return new ScrabrocGame(room, hooks, opts);
  }

  constructor(room, hooks, opts = {}) {
    super(room, hooks);
    this.podiumMs = SCR.podiumMs;
    const t = SCR.times.includes(opts?.temps) ? opts.temps : SCR.defaultTime;
    const secs = parseInt(t, 10) * 60;
    this.turnMs = process.env.PB_FAST ? secs * 100 : secs * 1000;
    this.order = shuffle(this.active().map((p) => p.pid));
    this.bag = makeBag(this.order.length);
    this.board = Array.from({ length: 15 }, () => Array(15).fill(null));
    this.racks = new Map(this.order.map((pid) => [pid, []]));
    this.points = new Map(this.order.map((pid) => [pid, 0]));
    for (const pid of this.order) this.fill(pid);
    this.turn = -1;
    this.passes = 0;
    this.last = null;           // { seq, pid, kind: play|swap|pass, cells, words, total, bingo, auto }
    this.hist = [];
    this.seq = 0;
    this.plans = new Map();     // robots : coup calculé pour ce tour
  }

  get current() { return this.order[this.turn] ?? null; }

  name(pid) { return this.room.players.get(pid)?.name ?? '?'; }

  fill(pid) {
    const rack = this.racks.get(pid);
    while (rack.length < 7 && this.bag.length) rack.push(this.bag.pop());
  }

  start() {
    this.schedule(SCR.introMs, () => this.nextTurn());
  }

  nextTurn() {
    if (this.over || this.phase === 'podium') return;
    if (!this.order.length) return this.end(null);
    this.turn = (this.turn + 1) % this.order.length;
    this.phase = 'turn';
    this.turnSeq = (this.turnSeq || 0) + 1;
    const p = this.room.players.get(this.current);
    this.schedule(p?.connected ? this.turnMs : SCR.goneMs, () => this.pass(this.current, true));
    this.changed();
  }

  note(e) {
    this.last = { seq: ++this.seq, ...e };
    this.hist.unshift({ pid: e.pid, kind: e.kind, words: (e.words || []).map((w) => w.w), total: e.total || 0, n: e.n });
    this.hist.length = Math.min(this.hist.length, 10);
  }

  // Lettres demandées : [{ r, c, i, l? }] (i = place sur le chevalet, l = lettre choisie pour un joker)
  placedFrom(pid, tiles) {
    const rack = this.racks.get(pid);
    if (!Array.isArray(tiles) || !tiles.length || tiles.length > 7) return null;
    const used = new Set();
    const out = [];
    for (const t of tiles) {
      if (!t || !Number.isInteger(t.i) || t.i < 0 || t.i >= rack.length || used.has(t.i)) return null;
      if (!Number.isInteger(t.r) || !Number.isInteger(t.c)) return null;
      used.add(t.i);
      const l = rack[t.i];
      if (l === '?') {
        const want = String(t.l || '').toUpperCase();
        if (!/^[A-Z]$/.test(want)) return null;
        out.push({ r: t.r, c: t.c, l: want, j: true, i: t.i });
      } else out.push({ r: t.r, c: t.c, l, j: false, i: t.i });
    }
    return out;
  }

  play(pid, tiles) {
    if (this.phase !== 'turn' || pid !== this.current) return;
    const placed = this.placedFrom(pid, tiles);
    if (!placed) return this.hooks.sendTo(pid, { t: 'scr_refused', msg: 'Coup impossible' });
    const ev = evaluate(this.board, placed);
    if (!ev.ok) return this.hooks.sendTo(pid, { t: 'scr_refused', msg: ev.err });
    for (const p of placed) this.board[p.r][p.c] = { l: p.l, j: p.j };
    const rack = this.racks.get(pid);
    for (const i of placed.map((p) => p.i).sort((a, b) => b - a)) rack.splice(i, 1);
    this.points.set(pid, this.points.get(pid) + ev.total);
    this.passes = 0;
    this.fill(pid);
    this.note({ pid, kind: 'play', cells: placed.map(({ r, c }) => [r, c]), words: ev.words, total: ev.total, bingo: ev.bingo });
    if (!rack.length && !this.bag.length) return this.end(pid);
    this.nextTurn();
  }

  swap(pid, idx) {
    if (this.phase !== 'turn' || pid !== this.current) return;
    const rack = this.racks.get(pid);
    if (!Array.isArray(idx) || !idx.length || this.bag.length < 7) return;
    const set = [...new Set(idx)].filter((i) => Number.isInteger(i) && i >= 0 && i < rack.length).sort((a, b) => b - a);
    if (!set.length) return;
    const out = set.map((i) => rack.splice(i, 1)[0]);
    this.fill(pid);
    this.bag.push(...out);
    this.bag = shuffle(this.bag);
    this.passes++;
    this.note({ pid, kind: 'swap', n: out.length });
    this.afterPass();
  }

  pass(pid, auto = false) {
    if (this.phase !== 'turn' || pid !== this.current) return;
    this.passes++;
    this.note({ pid, kind: 'pass', auto });
    this.afterPass();
  }

  afterPass() {
    if (this.passes >= Math.max(4, this.order.length * 2)) return this.end(null);
    this.nextTurn();
  }

  // Fin : celui qui a vidé son chevalet gagne la valeur des lettres restantes des autres
  end(out) {
    if (this.phase === 'podium') return;
    let bonus = 0;
    for (const pid of this.order) {
      if (pid === out) continue;
      const v = this.racks.get(pid).reduce((a, l) => a + VAL[l], 0);
      this.points.set(pid, this.points.get(pid) - v);
      bonus += v;
    }
    if (out) this.points.set(out, this.points.get(out) + bonus);
    for (const pid of this.order) this.addPoints(pid, Math.max(0, this.points.get(pid)));
    this.podium(SCR.podiumMs);
  }

  onMessage(p, m) {
    if (m.t === 'scr_play') return this.play(p.pid, m.tiles);
    if (m.t === 'scr_swap') return this.swap(p.pid, m.idx);
    if (m.t === 'scr_pass') return this.pass(p.pid);
    // Aperçu : le téléphone demande ce que vaut son coup (mots, points, erreur) avant de valider
    if (m.t === 'scr_check') {
      if (p.pid !== this.current || this.phase !== 'turn') return;
      const placed = this.placedFrom(p.pid, m.tiles);
      const ev = placed ? evaluate(this.board, placed) : { ok: false, err: '' };
      return this.hooks.sendTo(p.pid, { t: 'scr_preview', key: m.key, ok: ev.ok, err: ev.err || null, words: ev.words || [], total: ev.total || 0, bingo: !!ev.bingo });
    }
    this.hostCommand(p, m, () => {
      if (this.phase === 'intro') this.nextTurn();
      else if (this.phase === 'turn') this.pass(this.current, true);
    });
  }

  hostCommand(p, m, next) {
    if (m.t === 'game_end' && p.pid === this.room.hostPid && this.phase !== 'podium') { this.end(null); return true; }
    return super.hostCommand(p, m, next);
  }

  onPlayerGone(p) {
    if (this.phase === 'turn' && p.pid === this.current) this.schedule(SCR.goneMs, () => this.pass(p.pid, true));
  }

  // ---------------------------------------------------------------- robots
  // Le calcul (tous les mots du dictionnaire autour des lettres posées) se fait par petits
  // morceaux pour ne pas bloquer le serveur ; une fois fini, le coup est joué au tour suivant de botsTick.
  botAction(pid, level) {
    if (this.phase !== 'turn' || this.current !== pid) return null;
    const plan = this.plans.get(pid);
    if (!plan || plan.turn !== this.turnSeq) {
      this.plans.set(pid, { turn: this.turnSeq, busy: true });
      this.searchMoves(pid, level, this.turnSeq);
      return null;
    }
    if (plan.busy) return null;
    if (plan.move) return { m: { t: 'scr_play', tiles: plan.move }, ms: botMs(1500, 3500) };
    if (this.bag.length >= 7) return { m: { t: 'scr_swap', idx: [0, 1, 2, 3, 4, 5, 6].slice(0, this.racks.get(pid).length) }, ms: botMs(1500, 2500) };
    return { m: { t: 'scr_pass' }, ms: botMs(1500, 2500) };
  }

  async searchMoves(pid, level, turnSeq) {
    const rackArr = this.racks.get(pid);
    const rack = {};
    let jokers = 0;
    for (const l of rackArr) if (l === '?') jokers++; else rack[l] = (rack[l] || 0) + 1;
    const board = this.board;
    const at = (r, c) => (r >= 0 && r < 15 && c >= 0 && c < 15 ? board[r][c] : undefined);
    const first = board.every((row) => row.every((x) => !x));
    const anchors = [];
    board.forEach((row, r) => row.forEach((t, c) => t && anchors.push([r, c, t.l])));
    const moves = [];
    const tryPlace = (w, r0, c0, dr, dc) => {
      const er = r0 + dr * (w.length - 1);
      const ec = c0 + dc * (w.length - 1);
      if (r0 < 0 || c0 < 0 || er > 14 || ec > 14) return;
      if (at(r0 - dr, c0 - dc) || at(er + dr, ec + dc)) return;
      const need = { ...rack };
      let jk = jokers;
      const pl = [];
      for (let i = 0; i < w.length; i++) {
        const r = r0 + dr * i;
        const c = c0 + dc * i;
        const t = at(r, c);
        const l = w[i];
        if (t) { if (t.l !== l) return; continue; }
        if (need[l]) { need[l]--; pl.push({ r, c, l, j: false }); } else if (jk) { jk--; pl.push({ r, c, l, j: true }); } else return;
      }
      if (!pl.length || (pl.length === w.length && !first)) return;
      const ev = evaluate(board, pl);
      if (ev.ok) moves.push({ pl, total: ev.total });
    };
    const words = BOT_WORDS;
    const CHUNK = 3000;
    for (let start = 0; start < words.length; start += CHUNK) {
      if (this.over || this.turnSeq !== turnSeq) return;
      for (let k = start; k < Math.min(words.length, start + CHUNK); k++) {
        const w = words[k];
        let miss = 0;
        const cnt = {};
        for (const l of w) { cnt[l] = (cnt[l] || 0) + 1; if (cnt[l] > (rack[l] || 0)) miss++; }
        if (miss > jokers + (first ? 0 : 3)) continue;
        if (first) { for (let i = 0; i < w.length; i++) tryPlace(w, 7, 7 - i, 0, 1); continue; }
        for (const [r, c, L] of anchors) {
          for (let i = 0; i < w.length; i++) {
            if (w[i] !== L) continue;
            tryPlace(w, r, c - i, 0, 1);
            tryPlace(w, r - i, c, 1, 0);
          }
        }
      }
      await new Promise((res) => setImmediate(res));
    }
    if (this.over || this.turnSeq !== turnSeq) return;
    moves.sort((a, b) => b.total - a.total);
    let m = moves[0];
    if (level !== 'malin' && moves.length) {
      const short = moves.filter((x) => x.pl.length <= 4);
      const pool = short.length ? short : moves;
      m = pool[Math.min(pool.length - 1, Math.floor(pool.length * (0.35 + Math.random() * 0.5)))];
    }
    let move = null;
    if (m) {
      // Retrouver la place de chaque lettre sur le chevalet
      const free = rackArr.map((l, i) => ({ l, i }));
      move = m.pl.map((p) => {
        const k = free.findIndex((f) => (p.j ? f.l === '?' : f.l === p.l));
        const { i } = free.splice(k, 1)[0];
        return p.j ? { r: p.r, c: p.c, i, l: p.l } : { r: p.r, c: p.c, i };
      });
    }
    this.plans.set(pid, { turn: turnSeq, busy: false, move });
    this.changed();
  }

  // ---------------------------------------------------------------- état

  publicState() {
    return {
      ...this.base('scrabroc'),
      seq: this.seq,
      board: this.board.map((row) => row.map((t) => (t ? (t.j ? `${t.l.toLowerCase()}` : t.l) : ''))),
      bag: this.bag.length,
      current: this.phase === 'turn' ? this.current : null,
      players: this.order.map((pid) => ({ pid, score: this.points.get(pid), rack: this.racks.get(pid).length })),
      last: this.last,
      hist: this.hist,
    };
  }

  playerState(pid) {
    const r = this.ranking().find((x) => x.pid === pid);
    return {
      pid,
      inGame: this.racks.has(pid),
      myTurn: this.phase === 'turn' && pid === this.current,
      rack: this.racks.get(pid) ?? [],
      canSwap: this.bag.length >= 7,
      score: r?.score ?? 0,
      rank: r?.rank ?? null,
      players: this.ranking().length,
    };
  }
}

