// Skip-Broc : cartes de 1 à 12 (12 de chaque) et 18 jokers ★ ; 2 paquets au-delà de 6 joueurs.
// Chacun a un talon caché (seule la carte du dessus est visible), une main de 5 cartes et
// 4 défausses. Au milieu, 4 piles communes qu'on monte de 1 à 12 (le ★ vaut le chiffre attendu ;
// une pile complète retourne dans la pioche). À son tour : main complétée à 5, on pose autant
// qu'on peut (main, dessus du talon, dessus d'une défausse ; main vide → 5 nouvelles cartes),
// puis on finit en posant une carte de sa main sur une de ses défausses.
// Le premier qui vide son talon gagne.
import crypto from 'node:crypto';
import { BaseGame, botMs, fastTimings, shuffle } from './common.js';

export const SBR = fastTimings({
  introMs: 10000,
  turnMs: 35000,           // temps pour un tour (prolongé de 6 s à chaque carte posée, 35 s max)
  bonusMs: 6000,
  goneMs: 3000,
  podiumMs: 25000,
  sizes: [10, 20, 30],     // cartes au talon (option de l'hôte)
  defaultSize: 20,
  winPoints: 1000,
  perCard: 30,             // les autres : 30 points par carte sortie de leur talon
});

const STOCK_LABEL = (n) => `${n} cartes`;
export const STOCK_OPTIONS = SBR.sizes.map(STOCK_LABEL);

export function makeDeck(players) {
  const packs = players > 6 ? 2 : 1;
  const d = [];
  let id = 0;
  for (let p = 0; p < packs; p++) {
    for (let v = 1; v <= 12; v++) for (let k = 0; k < 12; k++) d.push({ id: id++, v });
    for (let k = 0; k < 18; k++) d.push({ id: id++, v: 0 });
  }
  return shuffle(d);
}

const last = (a) => a[a.length - 1];
export const needOf = (pile) => pile.length + 1;
export const fits = (card, pile) => !!card && (card.v === 0 || card.v === needOf(pile));
const label = (c) => (c.v === 0 ? '★' : String(c.v));

export class SkipBrocGame extends BaseGame {
  static id = 'skipbroc';

  static async create(room, opts, hooks) {
    return new SkipBrocGame(room, hooks, opts);
  }

  constructor(room, hooks, opts = {}) {
    super(room, hooks);
    this.podiumMs = SBR.podiumMs;
    const size = SBR.sizes.find((n) => STOCK_LABEL(n) === opts?.talon) ?? SBR.defaultSize;
    this.order = shuffle(this.active().map((p) => p.pid));
    this.draw = makeDeck(this.order.length);
    // Un talon plus petit si beaucoup de joueurs (assez de cartes pour la pioche)
    this.size = Math.min(size, Math.floor((this.draw.length * 0.55) / Math.max(1, this.order.length)));
    this.recycle = [];
    this.builds = [[], [], [], []];
    this.stock = new Map();
    this.hands = new Map();
    this.discs = new Map();
    for (const pid of this.order) {
      this.stock.set(pid, this.draw.splice(0, this.size));
      this.hands.set(pid, []);
      this.discs.set(pid, [[], [], [], []]);
    }
    this.turn = -1;
    this.event = null;
    this.seq = 0;
    this.winner = null;
  }

  get current() { return this.order[this.turn] ?? null; }

  start() {
    this.schedule(SBR.introMs, () => this.nextTurn());
  }

  name(pid) { return this.room.players.get(pid)?.name ?? '?'; }

  pull() {
    if (!this.draw.length) {
      this.draw = shuffle(this.recycle);
      this.recycle = [];
    }
    return this.draw.pop() ?? null;
  }

  fill(pid) {
    const hand = this.hands.get(pid);
    while (hand.length < 5) {
      const c = this.pull();
      if (!c) break;
      hand.push(c);
    }
  }

  note(e) {
    this.event = { seq: ++this.seq, ...e };
  }

  nextTurn() {
    if (this.over || this.phase === 'podium') return;
    if (!this.order.length) return this.end();
    this.turn = (this.turn + 1) % this.order.length;
    const pid = this.current;
    this.fill(pid);
    this.phase = 'turn';
    this.turnEnds = Date.now() + SBR.turnMs;
    const p = this.room.players.get(pid);
    this.schedule(p?.connected ? SBR.turnMs : SBR.goneMs, () => this.timeout());
    this.changed();
  }

  // Temps écoulé (ou joueur absent) : on défausse pour lui la carte la plus haute
  timeout() {
    if (this.phase !== 'turn') return;
    const pid = this.current;
    const hand = this.hands.get(pid);
    if (!hand.length) return this.nextTurn();
    let i = 0;
    for (let k = 1; k < hand.length; k++) if (hand[k].v > hand[i].v) i = k;
    const discs = this.discs.get(pid);
    let d = discs.findIndex((x) => last(x)?.v === hand[i].v);
    if (d < 0) d = discs.findIndex((x) => !x.length);
    if (d < 0) d = 0;
    this.discard(pid, i, d, true);
  }

  cardAt(pid, src, i) {
    if (src === 'hand') return this.hands.get(pid)[i];
    if (src === 'stock') return last(this.stock.get(pid));
    if (src === 'disc') return last(this.discs.get(pid)[i] ?? []);
    return undefined;
  }

  play(pid, src, i, b) {
    if (this.phase !== 'turn' || pid !== this.current) return false;
    if (!Number.isInteger(b) || b < 0 || b > 3) return false;
    if (src !== 'stock' && (!Number.isInteger(i) || i < 0 || i > (src === 'disc' ? 3 : 4))) return false;
    const card = this.cardAt(pid, src, i);
    const pile = this.builds[b];
    if (!fits(card, pile)) return false;
    if (src === 'hand') this.hands.get(pid).splice(i, 1);
    else if (src === 'stock') this.stock.get(pid).pop();
    else this.discs.get(pid)[i].pop();
    const as = needOf(pile);
    pile.push({ ...card, as });
    const e = { kind: 'play', pid, card, as, src, b, full: false, refill: false };
    if (pile.length === 12) {
      this.recycle.push(...pile.map(({ id, v }) => ({ id, v })));
      this.builds[b] = [];
      e.full = true;
    }
    if (!this.stock.get(pid).length) {
      this.winner = pid;
      this.note({ ...e, win: true });
      return this.end();
    }
    if (!this.hands.get(pid).length) {
      this.fill(pid);
      e.refill = true;
    }
    this.note(e);
    // Un peu plus de temps à chaque carte posée
    const left = this.turnEnds - Date.now();
    const ms = Math.min(SBR.turnMs, left + SBR.bonusMs);
    this.turnEnds = Date.now() + ms;
    this.schedule(ms, () => this.timeout());
    this.duration = SBR.turnMs; // la barre de temps garde la même échelle
    this.changed();
    return true;
  }

  discard(pid, i, d, auto = false) {
    if (this.phase !== 'turn' || pid !== this.current) return false;
    const hand = this.hands.get(pid);
    if (!Number.isInteger(i) || i < 0 || i >= hand.length || !Number.isInteger(d) || d < 0 || d > 3) return false;
    const card = hand.splice(i, 1)[0];
    this.discs.get(pid)[d].push(card);
    this.note({ kind: 'discard', pid, card, d, auto });
    this.nextTurn();
    return true;
  }

  end() {
    if (this.phase === 'podium') return;
    for (const pid of this.order) {
      const out = this.size - this.stock.get(pid).length;
      this.addPoints(pid, pid === this.winner ? SBR.winPoints : out * SBR.perCard);
    }
    this.podium(SBR.podiumMs);
  }

  onMessage(p, m) {
    if (m.t === 'sbr_play') return void this.play(p.pid, m.src, m.i, m.b);
    if (m.t === 'sbr_discard') return void this.discard(p.pid, m.i, m.d);
    this.hostCommand(p, m, () => {
      if (this.phase === 'intro') this.nextTurn();
      else if (this.phase === 'turn') this.timeout();
    });
  }

  hostCommand(p, m, next) {
    if (m.t === 'game_end' && p.pid === this.room.hostPid && this.phase !== 'podium') { this.end(); return true; }
    return super.hostCommand(p, m, next);
  }

  onPlayerGone(p) {
    if (this.phase === 'turn' && p.pid === this.current) this.schedule(SBR.goneMs, () => this.timeout());
  }

  // ---------------------------------------------------------------- robots

  // Malin : vide son talon d'abord (en comblant l'écart avec sa main, ses défausses ou un ★),
  // puis ses défausses, puis sa main sans trop aider le suivant ; garde ses ★ ; défausse sa plus
  // haute carte sur une défausse de même valeur ou juste au-dessus. Facile : pose ce qu'il voit.
  botMove(pid, level) {
    const malin = level === 'malin';
    const hand = this.hands.get(pid);
    const stock = this.stock.get(pid);
    const discs = this.discs.get(pid);
    const st = last(stock);
    for (let b = 0; b < 4; b++) if (fits(st, this.builds[b])) return { src: 'stock', i: 0, b };
    if (malin && st && st.v !== 0) {
      for (let b = 0; b < 4; b++) {
        const n = needOf(this.builds[b]);
        if (st.v < n || st.v - n > 4) continue;
        const hi = hand.findIndex((c) => c.v === n);
        if (hi >= 0) return { src: 'hand', i: hi, b };
        const di = discs.findIndex((x) => last(x)?.v === n);
        if (di >= 0) return { src: 'disc', i: di, b };
        const ji = hand.findIndex((c) => c.v === 0);
        if (ji >= 0 && st.v - n <= 1) return { src: 'hand', i: ji, b };
      }
    }
    for (let d = 0; d < 4; d++) {
      const c = last(discs[d]);
      if (!c || (malin && c.v === 0)) continue;
      for (let b = 0; b < 4; b++) if (fits(c, this.builds[b])) return { src: 'disc', i: d, b };
    }
    const next = this.order[(this.turn + 1) % this.order.length];
    const nv = next !== pid ? last(this.stock.get(next))?.v : undefined;
    for (let i = 0; i < hand.length; i++) {
      const c = hand[i];
      if (malin && c.v === 0) continue;
      for (let b = 0; b < 4; b++) {
        if (!fits(c, this.builds[b])) continue;
        if (malin && nv && needOf(this.builds[b]) + 1 === nv) continue;
        return { src: 'hand', i, b };
      }
    }
    return null;
  }

  botDiscard(pid, level) {
    const hand = this.hands.get(pid);
    const discs = this.discs.get(pid);
    if (level !== 'malin') return { i: crypto.randomInt(hand.length), d: crypto.randomInt(4) };
    const idx = hand.map((_, i) => i).filter((i) => hand[i].v !== 0).sort((a, b) => hand[b].v - hand[a].v);
    const i = idx.length ? idx[0] : 0;
    const v = hand[i].v;
    let d = discs.findIndex((x) => last(x)?.v === v);
    if (d < 0) d = discs.findIndex((x) => last(x)?.v === v + 1);
    if (d < 0) d = discs.findIndex((x) => !x.length);
    if (d < 0) d = discs.reduce((a, x, k) => (last(x).v > last(discs[a]).v ? k : a), 0);
    return { i, d };
  }

  botAction(pid, level) {
    if (this.phase !== 'turn' || this.current !== pid) return null;
    const mv = this.botMove(pid, level);
    if (mv) return { m: { t: 'sbr_play', ...mv }, ms: botMs(900, 1600) };
    if (!this.hands.get(pid).length) return null;
    const { i, d } = this.botDiscard(pid, level);
    return { m: { t: 'sbr_discard', i, d }, ms: botMs(1200, 2000) };
  }

  // ---------------------------------------------------------------- état

  publicState() {
    return {
      ...this.base('skipbroc'),
      seq: this.seq,
      size: this.size,
      builds: this.builds.map((p) => ({ top: last(p) ?? null, n: p.length })),
      draw: this.draw.length + this.recycle.length,
      current: this.phase === 'turn' ? this.current : null,
      players: this.order.map((pid) => ({
        pid,
        stockTop: last(this.stock.get(pid)) ?? null,
        stock: this.stock.get(pid).length,
        hand: this.hands.get(pid).length,
        discs: this.discs.get(pid).map((x) => ({ top: last(x) ?? null, n: x.length })),
      })),
      event: this.event,
      winner: this.winner,
    };
  }

  playerState(pid) {
    const r = this.ranking().find((x) => x.pid === pid);
    return {
      pid,
      inGame: this.stock.has(pid),
      myTurn: this.phase === 'turn' && pid === this.current,
      hand: this.hands.get(pid) ?? [],
      score: r?.score ?? 0,
      rank: r?.rank ?? null,
      players: this.ranking().length,
    };
  }
}
