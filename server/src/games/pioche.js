// Broc-Pioche : jeu de cartes. Chacun a sa main en secret sur son téléphone, la TV montre
// la pile. On pose une carte de la même couleur ou du même symbole ; le premier qui n'a
// plus de cartes gagne, puis on continue pour les places suivantes.
// Cartes : 4 couleurs (r, j, v, b), 0 à 9, « passe » (skip), « sens » (rev), +2 (p2),
// et les cartes noires « couleur » (joker) et +4 (p4).
// Règles maison : on peut renvoyer un +2 avec un +2, et un +2 ou un +4 avec un +4 (cumul).
// « Dernière carte ! » : qui tombe à une carte sans l'avoir annoncé peut être dénoncé
// (+2) jusqu'à ce que le joueur suivant joue.
// Les mains ne sont JAMAIS dans publicState() (TV et tous les téléphones le reçoivent).
import { BaseGame, botMs, fastTimings, shuffle } from './common.js';

export const PCH = fastTimings({
  hands: [5, 7],
  defaultHand: 7,
  introMs: 7000,
  turnMs: 25000,          // temps pour jouer
  goneMs: 4000,           // joueur déconnecté : son tour passe vite
  podiumMs: 25000,
  catchPenalty: 2,
  firstPoints: 1000,      // 1er : 1000, puis 150 de moins par place (100 minimum)
  stepPoints: 150,
  minPoints: 100,
});

export const COLORS = ['r', 'j', 'v', 'b'];

// Un paquet : par couleur un 0, deux 1-9, deux de chaque action ; 4 « couleur », 4 « +4 »
function makeDeck(decks) {
  const cards = [];
  let id = 0;
  for (let d = 0; d < decks; d++) {
    for (const c of COLORS) {
      cards.push({ id: id++, c, v: '0' });
      for (const v of ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'skip', 'rev', 'p2']) {
        cards.push({ id: id++, c, v });
        cards.push({ id: id++, c, v });
      }
    }
    for (let i = 0; i < 4; i++) {
      cards.push({ id: id++, c: 'w', v: 'joker' });
      cards.push({ id: id++, c: 'w', v: 'p4' });
    }
  }
  return shuffle(cards);
}

const isWild = (card) => card.c === 'w';

export class PiocheGame extends BaseGame {
  static id = 'pioche';

  static async create(room, opts, hooks) {
    return new PiocheGame(room, hooks, opts);
  }

  constructor(room, hooks, opts) {
    super(room, hooks);
    this.podiumMs = PCH.podiumMs;
    this.handSize = PCH.hands.includes(opts?.cards) ? opts.cards : PCH.defaultHand;
    this.order = shuffle(this.active().map((p) => p.pid)); // joueurs encore en jeu, dans l'ordre
    this.deck = makeDeck(this.order.length > 7 ? 2 : 1);
    this.discard = [];
    this.hands = new Map();
    for (const pid of this.order) this.hands.set(pid, this.deck.splice(0, this.handSize));
    // Première carte : un chiffre, pour démarrer simplement
    const first = this.deck.findIndex((c) => !isWild(c) && /^\d$/.test(c.v));
    this.discard.push(this.deck.splice(first, 1)[0]);
    this.color = this.top.c;
    this.dir = 1;
    this.turn = 0;            // index dans this.order
    this.pending = 0;         // cartes à piocher accumulées (+2 / +4)
    this.pendingKind = null;  // 'p2' ou 'p4'
    this.drawn = null;        // carte piochée ce tour (seule jouable ensuite)
    this.finished = [];       // pids, dans l'ordre d'arrivée
    this.said = new Set();    // ont annoncé « Dernière carte ! »
    this.exposed = null;      // a une carte sans l'avoir annoncé : peut être dénoncé
    this.event = null;        // dernière action, pour la TV { seq, k, pid, … }
    this.seq = 0;
  }

  get top() { return this.discard[this.discard.length - 1]; }
  get current() { return this.order[this.turn] ?? null; }

  start() {
    this.schedule(PCH.introMs, () => this.beginTurn(false));
  }

  // ---------------------------------------------------------------- règles

  playable(card) {
    if (this.pending > 0) {
      if (card.v === 'p4') return true;
      return card.v === 'p2' && this.pendingKind === 'p2';
    }
    if (isWild(card)) return true;
    return card.c === this.color || card.v === this.top.v;
  }

  // Pioche n cartes (la défausse est remélangée si la pioche est vide)
  take(pid, n) {
    const hand = this.hands.get(pid);
    let got = 0;
    for (let i = 0; i < n; i++) {
      if (this.deck.length === 0) {
        const top = this.discard.pop();
        this.deck = shuffle(this.discard);
        this.discard = [top];
      }
      const c = this.deck.pop();
      if (!c) break;
      hand.push(c);
      got++;
    }
    if (hand.length > 1) this.said.delete(pid);
    return got;
  }

  note(k, extra = {}) {
    this.event = { seq: ++this.seq, k, ...extra };
  }

  step(n = 1) {
    const len = this.order.length;
    if (!len) return;
    this.turn = (((this.turn + n * this.dir) % len) + len) % len;
  }

  // Début du tour du joueur courant
  beginTurn(advance = true) {
    if (advance) this.step();
    if (this.phase !== 'play') this.phase = 'play';
    this.drawn = null;
    const p = this.room.players.get(this.current);
    this.schedule(p?.connected ? PCH.turnMs : PCH.goneMs, () => this.timeout());
    this.changed();
  }

  // Temps écoulé : il pioche (ce qu'il doit, ou une carte) et passe
  timeout() {
    if (this.phase !== 'play') return;
    const pid = this.current;
    if (this.pending > 0) return this.drawPending(pid, true);
    if (!this.drawn) {
      const n = this.take(pid, 1);
      this.note('draw', { pid, n, late: true });
    } else this.note('pass', { pid, late: true });
    this.exposedEnds(pid);
    this.beginTurn();
  }

  drawPending(pid, late = false) {
    const n = this.take(pid, this.pending);
    this.note('draw', { pid, n, late, forced: true });
    this.pending = 0;
    this.pendingKind = null;
    this.exposedEnds(pid);
    this.beginTurn();
  }

  // Le joueur suivant agit : on ne peut plus dénoncer l'oubli d'avant
  exposedEnds(actor) {
    if (this.exposed && this.exposed !== actor) this.exposed = null;
  }

  play(pid, card, color) {
    const hand = this.hands.get(pid);
    hand.splice(hand.findIndex((c) => c.id === card.id), 1);
    this.discard.push(card);
    this.color = isWild(card) ? color : card.c;
    this.drawn = null;
    this.exposedEnds(pid);
    this.note('play', { pid, card, color: this.color });

    if (hand.length === 1 && !this.said.has(pid)) {
      this.exposed = pid;
      this.exposedN = (this.exposedN || 0) + 1;
    }
    if (hand.length === 0) return this.finish(pid, card);

    if (card.v === 'rev') {
      if (this.order.length === 2) return this.beginTurn(this.skipNext());
      this.dir = -this.dir;
    }
    if (card.v === 'skip') return this.beginTurn(this.skipNext());
    if (card.v === 'p2' || card.v === 'p4') {
      this.pending += card.v === 'p2' ? 2 : 4;
      this.pendingKind = card.v;
    }
    this.beginTurn();
  }

  // « Passe » : le suivant ne joue pas
  skipNext() {
    this.step();
    this.note('skip', { pid: this.current, by: this.event?.pid });
    return true;
  }

  // Plus de cartes : il prend sa place ; les effets de sa dernière carte s'appliquent
  finish(pid, card) {
    this.finished.push(pid);
    this.addPoints(pid, Math.max(PCH.minPoints, PCH.firstPoints - PCH.stepPoints * (this.finished.length - 1)));
    this.said.delete(pid);
    if (this.exposed === pid) this.exposed = null;
    this.note('out', { pid, place: this.finished.length, card });
    // On le retire de l'ordre, le tour revient au joueur d'avant pour que « suivant » tombe juste
    const i = this.order.indexOf(pid);
    this.order.splice(i, 1);
    if (this.dir === 1) this.turn = (i - 1 + this.order.length) % Math.max(1, this.order.length);
    else this.turn = i % Math.max(1, this.order.length);
    if (this.order.length <= 1) return this.end();
    if (card.v === 'rev' && this.order.length > 2) this.dir = -this.dir;
    if (card.v === 'p2' || card.v === 'p4') {
      this.pending += card.v === 'p2' ? 2 : 4;
      this.pendingKind = card.v;
    }
    if (card.v === 'skip' || (card.v === 'rev' && this.order.length === 2)) return this.beginTurn(this.skipNext());
    this.beginTurn();
  }

  // Fin : les joueurs restants sont classés au nombre de cartes (le moins en premier)
  end() {
    const rest = [...this.order].sort((a, b) => this.hands.get(a).length - this.hands.get(b).length);
    for (const pid of rest) {
      this.finished.push(pid);
      this.addPoints(pid, Math.max(PCH.minPoints, PCH.firstPoints - PCH.stepPoints * (this.finished.length - 1)));
    }
    this.order = [];
    this.exposed = null;
    this.pending = 0;
    this.podium(PCH.podiumMs);
  }

  // ---------------------------------------------------------------- messages

  onMessage(p, m) {
    if (this.phase === 'play' && this.hands.has(p.pid)) {
      const mine = p.pid === this.current;
      const hand = this.hands.get(p.pid);
      switch (m.t) {
        case 'pch_play': {
          if (!mine) return;
          const card = hand.find((c) => c.id === m.card);
          if (!card || !this.playable(card)) return;
          if (this.drawn && this.drawn !== card.id) return; // après avoir pioché : seulement la carte piochée
          if (isWild(card) && !COLORS.includes(m.color)) return;
          if (m.last === true && hand.length === 2) this.said.add(p.pid);
          this.play(p.pid, card, m.color);
          return;
        }
        case 'pch_draw': {
          if (!mine || this.drawn) return;
          if (this.pending > 0) return this.drawPending(p.pid);
          const before = hand.length;
          this.take(p.pid, 1);
          const card = hand.length > before ? hand[hand.length - 1] : null;
          this.note('draw', { pid: p.pid, n: card ? 1 : 0 });
          this.exposedEnds(p.pid);
          // La carte piochée se joue tout de suite si elle peut, sinon le tour passe
          if (card && this.playable(card)) {
            this.drawn = card.id;
            this.changed();
          } else this.beginTurn();
          return;
        }
        case 'pch_pass': {
          if (!mine || !this.drawn) return;
          this.note('pass', { pid: p.pid });
          this.beginTurn();
          return;
        }
        case 'pch_last': {
          if (hand.length > 2) return;
          this.said.add(p.pid);
          if (this.exposed === p.pid) this.exposed = null;
          this.note('last', { pid: p.pid });
          this.changed();
          return;
        }
        case 'pch_catch': {
          const who = this.exposed;
          if (!who || who === p.pid || m.pid !== who) return;
          this.exposed = null;
          const n = this.take(who, PCH.catchPenalty);
          this.note('catch', { pid: who, by: p.pid, n });
          this.changed();
          return;
        }
      }
    }
    this.hostCommand(p, m, () => {
      if (this.phase === 'intro') this.beginTurn(false);
      else if (this.phase === 'play') this.timeout(); // « Suivant » : le joueur qui traîne passe son tour
    });
  }

  // ---------------------------------------------------------------- robots

  // Dénonce qui a oublié « Dernière carte ! » (Malin presque toujours et vite, Facile parfois) ;
  // à son tour : pose une carte (Malin : la couleur qu'il a le plus, garde ses jokers, attaque
  // le suivant s'il n'a presque plus de cartes ; Facile : au hasard), sinon pioche.
  botAction(pid, level) {
    if (this.phase !== 'play') return null;
    const hand = this.hands.get(pid);
    if (!hand) return null;
    const malin = level === 'malin';
    if (this.exposed && this.exposed !== pid) {
      const go = this.botMemo(`${pid}:catch:${this.exposedN}`, () => Math.random() < (malin ? 0.85 : 0.4));
      if (go) return { m: { t: 'pch_catch', pid: this.exposed }, ms: malin ? botMs(1200, 2500) : botMs(2500, 4500) };
    }
    if (this.current !== pid) return null;
    const ms = botMs(1500, 3000);
    const playable = hand.filter((c) => this.playable(c) && (!this.drawn || c.id === this.drawn));
    if (!playable.length) return { m: { t: this.drawn ? 'pch_pass' : 'pch_draw' }, ms };
    const count = { r: 0, j: 0, v: 0, b: 0 };
    for (const c of hand) if (!isWild(c)) count[c.c]++;
    const nextPid = this.order[(((this.turn + this.dir) % this.order.length) + this.order.length) % this.order.length];
    const nextLow = nextPid !== pid && (this.hands.get(nextPid)?.length ?? 9) <= 2;
    const card = this.botMemo(`${pid}:play:${hand.length}:${this.top.id}:${this.drawn}:${this.pending}`, () => {
      if (!malin) {
        const plain = playable.filter((c) => !isWild(c));
        const from = plain.length && Math.random() < 0.7 ? plain : playable;
        return from[Math.floor(Math.random() * from.length)];
      }
      const value = (c) => {
        let s = isWild(c) ? (c.v === 'p4' ? -12 : -6) : 10 + count[c.c];
        if (['skip', 'rev', 'p2'].includes(c.v)) s += nextLow ? 10 : 1;
        if (c.v === 'p4' && nextLow) s += 14;
        return s;
      };
      return playable.reduce((a, b) => (value(b) > value(a) ? b : a));
    });
    if (!hand.includes(card) || !playable.includes(card)) return null;
    let color;
    if (isWild(card)) {
      color = COLORS.reduce((a, b) => (count[b] > count[a] ? b : a));
      if (!count[color]) color = this.botMemo(`${pid}:color:${card.id}`, () => COLORS[Math.floor(Math.random() * 4)]);
    }
    // « Dernière carte ! » : Malin ne l'oublie jamais, Facile une fois sur trois
    const last = hand.length === 2 && this.botMemo(`${pid}:last:${card.id}`, () => malin || Math.random() < 0.65);
    return { m: { t: 'pch_play', card: card.id, color, last }, ms };
  }

  hostCommand(p, m, next) {
    // « Arrêter » : classement au nombre de cartes restantes
    if (m.t === 'game_end' && p.pid === this.room.hostPid && this.phase !== 'podium') { this.end(); return true; }
    return super.hostCommand(p, m, next);
  }

  onPlayerGone(p) {
    // Son tour passe vite s'il est parti pendant qu'il devait jouer
    if (this.phase === 'play' && p.pid === this.current) this.schedule(PCH.goneMs, () => this.timeout());
  }

  // ---------------------------------------------------------------- état

  publicState() {
    const s = {
      ...this.base('pioche'),
      seq: this.seq,
      // Joueurs en jeu dans l'ordre de passage, avec seulement leur NOMBRE de cartes
      order: this.order.map((pid) => ({ pid, n: this.hands.get(pid)?.length ?? 0, said: this.said.has(pid) })),
      finished: this.finished,
      current: this.phase === 'play' ? this.current : null,
      dir: this.dir,
      top: this.top,
      color: this.color,
      pending: this.pending,
      deck: this.deck.length,
      exposed: this.exposed,
      event: this.event,
    };
    return s;
  }

  playerState(pid) {
    const r = this.ranking().find((x) => x.pid === pid);
    const hand = this.hands.get(pid);
    const mine = this.phase === 'play' && pid === this.current;
    const order = { r: 0, j: 1, v: 2, b: 3, w: 4 };
    const val = (v) => (/^\d$/.test(v) ? +v : { skip: 10, rev: 11, p2: 12, joker: 13, p4: 14 }[v]);
    return {
      inGame: !!hand,
      hand: hand ? [...hand].sort((a, b) => order[a.c] - order[b.c] || val(a.v) - val(b.v)) : [],
      playable: mine && hand ? hand.filter((c) => this.playable(c) && (!this.drawn || this.drawn === c.id)).map((c) => c.id) : [],
      drawn: mine ? this.drawn : null,
      myTurn: mine,
      place: this.finished.indexOf(pid) + 1 || null,
      score: r?.score ?? 0,
      rank: r?.rank ?? null,
      players: this.ranking().length,
    };
  }
}
