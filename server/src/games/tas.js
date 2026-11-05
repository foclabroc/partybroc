// Le tas de merde : jeu de rapidité (règles de l'utilisateur).
// Chaque manche : 4 cartes chacun (autant de valeurs que de joueurs, les 4 cartes de chaque valeur),
// le reste forme le tas au milieu. Tout le monde choisit en même
// temps une carte à passer à son voisin de gauche (`tas_pick`), puis les cartes passent.
// Celui qui réunit 4 cartes de même valeur (un carré) tape sur le tas (`tas_tap`) ; dès qu'il a tapé,
// tous les autres doivent taper le plus vite possible. Le dernier (ou ceux qui n'ont pas tapé à temps)
// pioche la carte du dessus du tas : sa valeur = les kilos de merde qu'il récolte. Le 7 est la
// chasse d'eau : tous ses kilos partent. Taper sans carré = 2 kilos. Le moins de kilos gagne.
import crypto from 'node:crypto';
import { BaseGame, botMs, fastTimings, shuffle } from './common.js';

export const TAS = fastTimings({
  introMs: 10000,
  dealMs: 2600,       // « Manche 2 / 5 »
  pickMs: 12000,      // temps pour choisir la carte à passer
  swapMs: 1300,       // les cartes passent au voisin
  tapMs: 4000,        // les autres ont 4 s pour taper
  penaltyMs: 7000,    // ordre des tapes + carte piochée
  podiumMs: 25000,
  tapCooldownMs: 1500,
  manches: [3, 5, 7],
  maxSwaps: 40,       // personne ne fait de carré : manche annulée
  falseKilos: 2,
});

const SUITS = ['c', 'k', 'p', 't'];
const RANKS = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'V', 'D', 'R'];

// 52 cartes, 104 au-delà de 10 joueurs (il en faut 4 par joueur + un tas)
export function makeDeck(players) {
  const d = [];
  let id = 0;
  for (let k = 0; k < (players > 10 ? 2 : 1); k++) for (const s of SUITS) for (const r of RANKS) d.push({ id: id++, r, s });
  return shuffle(d);
}

// Kilos d'une carte : l'as vaut le plus (11), 2 à 10 leur valeur, figures 10 ; le 7 est la chasse d'eau
export const kilosOf = (c) => (c.r === 'A' ? 11 : ['V', 'D', 'R'].includes(c.r) ? 10 : Number(c.r));
export const isFlush = (c) => c.r === '7';

// Valeur du carré dans la main (ou null)
export function carreOf(hand) {
  const n = new Map();
  for (const c of hand) n.set(c.r, (n.get(c.r) || 0) + 1);
  for (const [r, k] of n) if (k >= 4) return r;
  return null;
}

export class TasGame extends BaseGame {
  static id = 'tas';

  static async create(room, opts, hooks) {
    return new TasGame(room, hooks, opts);
  }

  constructor(room, hooks, opts = {}) {
    super(room, hooks);
    this.podiumMs = TAS.podiumMs;
    this.manches = TAS.manches.includes(opts?.manches) ? opts.manches : 5;
    this.order = shuffle(this.active().map((p) => p.pid));
    this.kilos = new Map(this.order.map((pid) => [pid, 0]));
    this.hands = new Map(this.order.map((pid) => [pid, []]));
    this.picks = new Map();
    this.pile = [];
    this.manche = 0;
    this.swaps = 0;
    this.first = null;        // qui a tapé le premier
    this.carre = null;        // ses 4 cartes
    this.taps = [];           // [{pid, ms}] dans l'ordre
    this.tapAt = 0;
    this.draws = [];          // [{pid, card, flush, kilos}]
    this.event = null;
    this.seq = 0;
    this.lastFalse = new Map();
  }

  start() {
    this.schedule(TAS.introMs, () => this.deal());
  }

  name(pid) { return this.room.players.get(pid)?.name ?? '?'; }
  connected(pid) { return !!this.room.players.get(pid)?.connected; }

  deal() {
    if (this.over || this.phase === 'podium') return;
    this.manche++;
    // Une valeur par joueur, ses 4 cartes en jeu (sinon un carré serait presque impossible) ;
    // tout le reste forme le tas
    const deck = makeDeck(this.order.length);
    const ranks = shuffle([...RANKS, ...RANKS]).filter((r, i, a) => this.order.length > 13 || a.indexOf(r) === i).slice(0, this.order.length);
    const play = [];
    for (const r of ranks) for (let k = 0; k < 4; k++) play.push(deck.splice(deck.findIndex((c) => c.r === r), 1)[0]);
    shuffle(play);
    for (const pid of this.order) this.hands.set(pid, play.splice(0, 4));
    this.pile = deck;
    this.passed = null;
    this.swaps = 0;
    this.first = null;
    this.carre = null;
    this.taps = [];
    this.draws = [];
    this.event = null;
    this.phase = 'deal';
    this.schedule(TAS.dealMs, () => this.pickPhase());
    this.changed();
  }

  pickPhase() {
    if (this.phase !== 'deal' && this.phase !== 'swap') return;
    if (this.swaps >= TAS.maxSwaps) {
      // Personne n'y arrive : on redistribue (la manche ne compte pas)
      this.manche--;
      return this.deal();
    }
    this.phase = 'pick';
    this.picks = new Map();
    this.schedule(TAS.pickMs, () => this.swap());
    this.changed();
  }

  pick(pid, id) {
    if (this.phase !== 'pick') return;
    const hand = this.hands.get(pid);
    if (!hand || !hand.some((c) => c.id === id)) return;
    if (this.picks.get(pid) === id) this.picks.delete(pid); // retouchée : on change d'avis
    else this.picks.set(pid, id);
    if (this.order.every((p) => this.picks.has(p) || !this.connected(p))) {
      this.schedule(TAS.swapMs / 3, () => this.swap());
    }
    this.changed();
  }

  // Carte passée au hasard (temps écoulé, joueur parti) : une de la valeur la moins nombreuse
  autoPick(pid) {
    const hand = this.hands.get(pid);
    const n = new Map();
    for (const c of hand) n.set(c.r, (n.get(c.r) || 0) + 1);
    const min = Math.min(...n.values());
    const cands = hand.filter((c) => n.get(c.r) === min);
    return cands[crypto.randomInt(cands.length)].id;
  }

  swap() {
    if (this.phase !== 'pick') return;
    const out = this.order.map((pid) => {
      const hand = this.hands.get(pid);
      const id = this.picks.get(pid) ?? this.autoPick(pid);
      return hand.splice(hand.findIndex((c) => c.id === id), 1)[0];
    });
    // La carte de order[i] va à order[i + 1] (le voisin de gauche)
    out.forEach((c, i) => this.hands.get(this.order[(i + 1) % this.order.length]).push(c));
    this.passed = new Map(this.order.map((pid, i) => [this.order[(i + 1) % this.order.length], out[i].id]));
    this.swaps++;
    this.picks = new Map();
    this.phase = 'swap';
    this.schedule(TAS.swapMs, () => this.pickPhase());
    this.changed();
  }

  tap(pid) {
    if (!this.hands.has(pid)) return;
    if (this.phase === 'pick' || this.phase === 'swap') {
      const r = carreOf(this.hands.get(pid));
      if (!r) {
        // Faux carré : 2 kilos (une fois par 1,5 s au plus)
        if (Date.now() - (this.lastFalse.get(pid) || 0) < TAS.tapCooldownMs) return;
        this.lastFalse.set(pid, Date.now());
        this.kilos.set(pid, this.kilos.get(pid) + TAS.falseKilos);
        this.event = { seq: ++this.seq, kind: 'false', pid };
        return this.changed();
      }
      this.first = pid;
      this.carre = this.hands.get(pid).filter((c) => c.r === r).slice(0, 4);
      this.tapAt = Date.now();
      this.taps = [{ pid, ms: 0 }];
      this.event = null;
      this.phase = 'tap';
      this.schedule(TAS.tapMs, () => this.penalty());
      return this.changed();
    }
    if (this.phase === 'tap' && !this.taps.some((t) => t.pid === pid)) {
      this.taps.push({ pid, ms: Date.now() - this.tapAt });
      if (this.order.every((p) => this.taps.some((t) => t.pid === p) || !this.connected(p))) {
        this.schedule(TAS.swapMs / 2, () => this.penalty());
      }
      this.changed();
    }
  }

  penalty() {
    if (this.phase !== 'tap') return;
    // Ceux qui n'ont pas tapé (et sont là) ; sinon le dernier qui a tapé
    const late = this.order.filter((p) => this.connected(p) && !this.taps.some((t) => t.pid === p));
    const losers = late.length ? late : [this.taps[this.taps.length - 1].pid];
    this.draws = losers.map((pid) => {
      const card = this.pile.shift() ?? makeDeck(1)[0];
      const flush = isFlush(card);
      const before = this.kilos.get(pid);
      const after = flush ? 0 : before + kilosOf(card);
      this.kilos.set(pid, after);
      return { pid, card, flush, before, after, late: late.includes(pid) };
    });
    this.phase = 'penalty';
    this.schedule(TAS.penaltyMs, () => (this.manche >= this.manches ? this.end() : this.deal()));
    this.changed();
  }

  // Classement au moins de kilos : 1000, puis 150 de moins par place (100 au minimum), ex æquo = même place
  end() {
    if (this.phase === 'podium') return;
    const ks = this.order.map((pid) => this.kilos.get(pid));
    for (const pid of this.order) {
      const place = ks.filter((k) => k < this.kilos.get(pid)).length;
      this.addPoints(pid, Math.max(100, 1000 - 150 * place));
    }
    this.podium(TAS.podiumMs);
  }

  onMessage(p, m) {
    switch (m.t) {
      case 'tas_pick': return this.pick(p.pid, m.id);
      case 'tas_tap': return this.tap(p.pid);
    }
    this.hostCommand(p, m, () => {
      if (this.phase === 'intro') this.deal();
      else if (this.phase === 'deal') this.pickPhase();
      else if (this.phase === 'pick') this.swap();
      else if (this.phase === 'swap') this.pickPhase();
      else if (this.phase === 'tap') this.penalty();
      else if (this.phase === 'penalty') (this.manche >= this.manches ? this.end() : this.deal());
    });
  }

  hostCommand(p, m, next) {
    if (m.t === 'game_end' && p.pid === this.room.hostPid && this.phase !== 'podium') { this.end(); return true; }
    return super.hostCommand(p, m, next);
  }

  // ---------------------------------------------------------------- robots
  // Ils gardent la valeur qu'ils ont le plus et passent une carte de la moins nombreuse.
  // Carré : ils tapent après un temps de réaction (Malin plus vite). Quelqu'un a tapé : ils suivent.
  botAction(pid, level) {
    const malin = level === 'malin';
    if (this.phase === 'tap') {
      if (this.taps.some((t) => t.pid === pid)) return null;
      const ms = this.botMemo(`${pid}:tap:${this.manche}`, () => (malin ? botMs(450, 1300) : botMs(650, 2200)));
      return { m: { t: 'tas_tap' }, ms };
    }
    if (this.phase !== 'pick' && this.phase !== 'swap') return null;
    if (carreOf(this.hands.get(pid))) {
      const ms = this.botMemo(`${pid}:carre:${this.manche}:${this.swaps}`, () => (malin ? botMs(700, 1800) : botMs(1200, 3500)));
      return { m: { t: 'tas_tap' }, ms };
    }
    if (this.phase === 'pick' && !this.picks.has(pid)) {
      const id = this.botMemo(`${pid}:pick:${this.manche}:${this.swaps}`, () => this.autoPick(pid));
      return { m: { t: 'tas_pick', id }, ms: botMs(900, 3000) };
    }
    return null;
  }

  // ---------------------------------------------------------------- état

  publicState() {
    const shown = this.phase === 'tap' || this.phase === 'penalty';
    return {
      ...this.base('tas'),
      seq: this.seq,
      manche: this.manche,
      manches: this.manches,
      swaps: this.swaps,
      pile: this.pile.length,
      players: this.order.map((pid) => ({
        pid,
        kilos: this.kilos.get(pid),
        picked: this.phase === 'pick' && this.picks.has(pid),
      })),
      first: shown ? this.first : null,
      carre: shown ? this.carre : null,
      taps: shown ? this.taps : [],
      draws: this.phase === 'penalty' ? this.draws : [],
      event: this.event,
    };
  }

  playerState(pid) {
    const r = this.ranking().find((x) => x.pid === pid);
    return {
      pid,
      inGame: this.hands.has(pid),
      hand: this.hands.get(pid) ?? [],
      picked: this.phase === 'pick' ? this.picks.get(pid) ?? null : null,
      got: this.passed?.get(pid) ?? null,   // carte reçue du voisin au dernier passage
      tapped: this.taps.some((t) => t.pid === pid),
      kilos: this.kilos.get(pid) ?? 0,
      score: r?.score ?? 0,
      rank: r?.rank ?? null,
      players: this.ranking().length,
    };
  }
}
