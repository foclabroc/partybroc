// Le Pouilleux : jeu de cartes classique (32 cartes jusqu'à 5 joueurs, 52 au-delà) sans le valet
// de trèfle : le valet de pique n'a plus de paire, c'est le Pouilleux.
// Toutes les cartes sont distribuées, chacun défausse ses paires (même valeur, même couleur).
// À son tour, on pioche une carte cachée chez le joueur suivant encore en jeu ; si elle fait une
// paire, elle part au milieu. Puis c'est à lui de piocher chez son voisin. Plus de cartes = sauvé.
// Le dernier, qui garde le valet de pique, est le Pouilleux (gage en option).
// Chacun range sa main comme il veut (`pou_order`) : les autres voient les dos dans ce même ordre
// (affichés en miroir par l'appli, comme vus d'en face). Le joueur qui pioche « hésite » sur une
// place (`pou_hover`), visible de tous ; on pioche une place, pas une carte : si le joueur visé
// range ou mélange sa main entre-temps, la carte sous cette place change.
import crypto from 'node:crypto';
import { BaseGame, botMs, fastTimings, shuffle } from './common.js';

export const POU = fastTimings({
  introMs: 9000,
  dealMs: 3500,            // « 4 paires défaussées à la distribution »
  turnMs: 25000,           // temps pour piocher (sinon une carte au hasard)
  goneMs: 3000,
  tookMs: 1700,            // le temps de voir la carte passer et la paire tomber
  revealMs: 9000,          // « Robert est le Pouilleux ! » + gage
  podiumMs: 25000,
  gages: ['Avec gage', 'Sans gage'],
});

export const GAGES = [
  'Faire le service des boissons au prochain tour',
  'Imiter une poule pendant 10 secondes',
  'Chanter le refrain de son choix',
  'Faire un compliment à chaque joueur',
  'Raconter une blague',
  'Parler avec un accent jusqu’à la prochaine partie',
  'Faire 10 squats',
  'Mimer un animal, les autres devinent',
  'Danser 15 secondes sans musique',
  'Dire « Je suis le Pouilleux » d’une voix de robot',
];

const SUITS = ['c', 'k', 'p', 't']; // cœur, carreau, pique, trèfle
const red = (s) => s === 'c' || s === 'k';
export const isPouilleux = (c) => c.r === 'V' && c.s === 'p';

export function makeDeck(players) {
  const ranks = players > 5
    ? ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'V', 'D', 'R', 'A']
    : ['7', '8', '9', '10', 'V', 'D', 'R', 'A'];
  const d = [];
  let id = 0;
  for (const s of SUITS) for (const r of ranks) if (!(r === 'V' && s === 't')) d.push({ id: id++, r, s });
  return shuffle(d);
}

export const pairOf = (hand, c) => hand.find((x) => x !== c && x.r === c.r && red(x.s) === red(c.s));

// Retire toutes les paires d'une main ; renvoie les paires retirées
export function dropPairs(hand) {
  const out = [];
  for (let k = 0; k < hand.length; k++) {
    const m = pairOf(hand, hand[k]);
    if (!m) continue;
    const c = hand[k];
    hand.splice(hand.indexOf(m), 1);
    hand.splice(hand.indexOf(c), 1);
    out.push([c, m]);
    k = -1;
  }
  return out;
}

export class PouilleuxGame extends BaseGame {
  static id = 'pouilleux';

  static async create(room, opts, hooks) {
    return new PouilleuxGame(room, hooks, opts);
  }

  constructor(room, hooks, opts = {}) {
    super(room, hooks);
    this.podiumMs = POU.podiumMs;
    this.withGage = opts?.gage !== 'Sans gage';
    this.order = shuffle(this.active().map((p) => p.pid));
    this.deck = makeDeck(this.order.length).length;
    this.hands = new Map(this.order.map((pid) => [pid, []]));
    makeDeck(this.order.length).forEach((c, i) => this.hands.get(this.order[i % this.order.length]).push(c));
    this.pile = [];
    this.dealt = 0;
    for (const pid of this.order) {
      const pairs = dropPairs(this.hands.get(pid));
      this.pile.push(...pairs);
      this.dealt += pairs.length;
    }
    this.saved = [];            // pids dans l'ordre où ils se sont sauvés
    this.cur = 0;               // index dans order du joueur qui pioche
    this.hover = null;          // place visée chez le joueur suivant (dans l'ordre de sa main)
    this.hovers = 0;            // nombre d'hésitations ce tour (robots)
    this.turnSeq = 0;
    this.event = null;
    this.seq = 0;
    this.loser = null;
    this.gage = null;
    for (const pid of this.order) if (!this.hands.get(pid).length) this.saved.push(pid);
  }

  isIn(pid) { return this.hands.has(pid) && !this.saved.includes(pid); }

  // Prochain joueur encore en jeu après l'index i
  nextIn(i) {
    for (let k = 1; k <= this.order.length; k++) {
      const j = (i + k) % this.order.length;
      if (this.isIn(this.order[j])) return j;
    }
    return i;
  }

  get current() { return this.order[this.cur] ?? null; }
  get target() { return this.order[this.nextIn(this.cur)] ?? null; }
  inGame() { return this.order.filter((pid) => this.isIn(pid)); }

  start() {
    this.schedule(POU.introMs, () => this.deal());
  }

  deal() {
    if (this.phase !== 'intro') return;
    this.phase = 'deal';
    if (this.inGame().length <= 1) return this.reveal();
    if (!this.isIn(this.current)) this.cur = this.nextIn(this.cur);
    this.schedule(POU.dealMs, () => this.nextTurn(false));
    this.changed();
  }

  nextTurn(advance = true) {
    if (this.over || this.phase === 'podium' || this.phase === 'reveal') return;
    if (this.inGame().length <= 1) return this.reveal();
    if (advance) this.cur = this.nextCur ?? this.nextIn(this.cur);
    this.nextCur = null;
    this.phase = 'turn';
    this.hover = null;
    this.hovers = 0;
    this.turnSeq++;
    const p = this.room.players.get(this.current);
    this.schedule(p?.connected ? POU.turnMs : POU.goneMs, () => this.take(this.current, null, true));
    this.changed();
  }

  name(pid) { return this.room.players.get(pid)?.name ?? '?'; }

  setHover(pid, i) {
    if (this.phase !== 'turn' || pid !== this.current) return;
    const n = this.hands.get(this.target).length;
    this.hover = Number.isInteger(i) && i >= 0 && i < n ? i : null;
    this.hovers++;
    this.changed();
  }

  // Le joueur en cours prend la carte à la place i chez le suivant (i absent : au hasard)
  take(pid, i, auto = false) {
    if (this.phase !== 'turn' || pid !== this.current) return;
    const from = this.target;
    const hand = this.hands.get(from);
    if (!hand.length) return;
    if (!Number.isInteger(i) || i < 0 || i >= hand.length) i = auto ? crypto.randomInt(hand.length) : null;
    if (i === null) return;
    const card = hand.splice(i, 1)[0];
    const mine = this.hands.get(pid);
    mine.push(card);
    const m = pairOf(mine, card);
    let pair = null;
    if (m) {
      mine.splice(mine.indexOf(card), 1);
      mine.splice(mine.indexOf(m), 1);
      this.pile.push([card, m]);
      pair = [card, m];
    }
    const saved = [];
    for (const who of [from, pid]) {
      if (!this.hands.get(who).length && !this.saved.includes(who)) {
        this.saved.push(who);
        saved.push(who);
      }
    }
    this.event = { seq: ++this.seq, pid, from, i, pair, saved, auto };
    this.hover = null;
    // Ensuite, c'est au joueur chez qui on a pioché (ou au suivant s'il est sauvé)
    this.nextCur = this.isIn(from) ? this.order.indexOf(from) : this.nextIn(this.cur);
    this.phase = 'took';
    this.schedule(POU.tookMs, () => this.nextTurn());
    this.changed();
  }

  reveal() {
    if (this.phase === 'reveal' || this.phase === 'podium') return;
    this.loser = this.inGame()[0] ?? null;
    this.gage = this.withGage ? GAGES[crypto.randomInt(GAGES.length)] : null;
    this.phase = 'reveal';
    this.schedule(POU.revealMs, () => this.end());
    this.changed();
  }

  // Points : 1000 pour le premier sauvé, 150 de moins à chaque place (100 au minimum), 0 pour le Pouilleux.
  // Arrêtée en cours : ceux encore en jeu sont classés au nombre de cartes, le valet de pique en dernier.
  end() {
    if (this.phase === 'podium') return;
    const rest = this.inGame().sort((a, b) => {
      const pa = this.hands.get(a).some(isPouilleux) ? 1 : 0;
      const pb = this.hands.get(b).some(isPouilleux) ? 1 : 0;
      return pa - pb || this.hands.get(a).length - this.hands.get(b).length;
    });
    const ranked = [...this.saved, ...rest];
    ranked.forEach((pid, k) => {
      const pouilleux = this.hands.get(pid).some(isPouilleux);
      this.addPoints(pid, pouilleux ? 0 : Math.max(100, 1000 - 150 * k));
    });
    this.podium(POU.podiumMs);
  }

  // Celui chez qui on pioche ne peut plus toucher à l'ordre de sa main pendant que l'autre choisit
  handLocked(pid) { return this.phase === 'turn' && this.target === pid; }

  onMessage(p, m) {
    switch (m.t) {
      case 'pou_hover': return this.setHover(p.pid, m.i);
      case 'pou_take': return this.take(p.pid, m.i);
      case 'pou_order': {
        // Nouvel ordre de sa main : la liste des identifiants de ses cartes, toutes, une fois chacune
        const hand = this.hands.get(p.pid);
        if (this.handLocked(p.pid)) return;
        if (!hand || !Array.isArray(m.ids) || m.ids.length !== hand.length) return;
        const byId = new Map(hand.map((c) => [c.id, c]));
        const next = m.ids.map((id) => byId.get(id));
        if (next.some((c) => !c) || new Set(m.ids).size !== hand.length) return;
        hand.splice(0, hand.length, ...next);
        return this.changed();
      }
      case 'pou_shuffle': {
        const hand = this.hands.get(p.pid);
        if (!hand || hand.length < 2 || this.handLocked(p.pid)) return;
        hand.splice(0, hand.length, ...shuffle(hand));
        this.event = { seq: ++this.seq, kind: 'shuffle', pid: p.pid };
        return this.changed();
      }
    }
    this.hostCommand(p, m, () => {
      if (this.phase === 'intro') this.deal();
      else if (this.phase === 'deal' || this.phase === 'took') this.nextTurn(this.phase === 'took');
      else if (this.phase === 'turn') this.take(this.current, null, true);
      else if (this.phase === 'reveal') this.end();
    });
  }

  hostCommand(p, m, next) {
    if (m.t === 'game_end' && p.pid === this.room.hostPid && this.phase !== 'podium') { this.end(); return true; }
    return super.hostCommand(p, m, next);
  }

  onPlayerGone(p) {
    if (this.phase === 'turn' && p.pid === this.current) this.schedule(POU.goneMs, () => this.take(p.pid, null, true));
  }

  // ---------------------------------------------------------------- robots
  // Le robot qui pioche hésite sur 1 à 3 places, puis prend la dernière. Le robot Malin qui a le
  // valet de pique mélange sa main quand c'est à lui de piocher (7 fois sur 10) : visé, il ne peut plus.
  botAction(pid, level) {
    if (this.phase !== 'turn') return null;
    if (this.current === pid && level === 'malin' && this.hands.get(pid).some(isPouilleux)) {
      const key = `${pid}:${this.turnSeq}`;
      this.botMixed ??= new Set();
      const mix = this.botMemo(`${key}:mix`, () => Math.random() < 0.7);
      if (mix && !this.botMixed.has(key)) {
        this.botMixed.add(key);
        return { m: { t: 'pou_shuffle' }, ms: botMs(300, 900) };
      }
    }
    if (this.current !== pid) return null;
    const n = this.hands.get(this.target).length;
    if (!n) return null;
    const want = this.botMemo(`${pid}:hesit:${this.turnSeq}`, () => 1 + crypto.randomInt(3));
    if (this.hovers < want) {
      const i = this.botMemo(`${pid}:h${this.hovers}:${this.turnSeq}`, () => crypto.randomInt(n));
      return { m: { t: 'pou_hover', i: Math.min(i, n - 1) }, ms: this.hovers ? botMs(700, 1400) : botMs(900, 1600) };
    }
    return { m: { t: 'pou_take', i: Math.min(this.hover ?? 0, n - 1) }, ms: botMs(800, 1400) };
  }

  // ---------------------------------------------------------------- état

  publicState() {
    const playing = ['turn', 'took'].includes(this.phase);
    const revealed = this.phase === 'reveal';
    return {
      ...this.base('pouilleux'),
      seq: this.seq,
      deck: this.deck,
      dealt: this.dealt,
      current: playing ? this.current : null,
      target: this.phase === 'turn' ? this.target : null,
      hover: this.phase === 'turn' ? this.hover : null,
      players: this.order.map((pid) => ({
        pid,
        n: this.hands.get(pid).length,
        saved: this.saved.includes(pid) ? this.saved.indexOf(pid) + 1 : null,
      })),
      pile: this.pile.length,
      pairs: this.pile.slice(-6),
      event: this.event,
      loser: revealed ? this.loser : null,
      loserCard: revealed && this.loser ? this.hands.get(this.loser)[0] ?? null : null,
      gage: revealed ? this.gage : null,
    };
  }

  playerState(pid) {
    const r = this.ranking().find((x) => x.pid === pid);
    return {
      pid,
      inGame: this.hands.has(pid),
      myTurn: this.phase === 'turn' && pid === this.current,
      hand: this.hands.get(pid) ?? [],
      saved: this.saved.includes(pid) ? this.saved.indexOf(pid) + 1 : null,
      score: r?.score ?? 0,
      rank: r?.rank ?? null,
      players: this.ranking().length,
    };
  }
}
