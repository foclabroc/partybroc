// Jeu de l'oie : 63 cases en spirale, deux dés tirés par le serveur.
// Cases : oies (on rejoue la même valeur), pont (6 → 12), hôtel (19 : 2 tours sans jouer),
// puits (31) et prison (52) : bloqué jusqu'à ce qu'un autre y tombe et prenne sa place,
// labyrinthe (42 → 30), mort (58 → départ), arrivée 63 (il faut tomber pile : sinon on recule
// de l'excédent). Premier lancer : 6 + 3 → 26, 5 + 4 → 53 (règle classique).
// Cases Défi (10, 26, 37, 48) : une question du quiz, bonne réponse +3, sinon -3.
// Le premier sur la 63 gagne ; les autres sont classés selon leur case.
import crypto from 'node:crypto';
import { db } from '../db.js';
import { BaseGame, fastTimings, shuffle } from './common.js';

export const OIE = fastTimings({
  introMs: 9000,
  turnMs: 20000,          // temps pour lancer (sinon les dés sont lancés tout seuls)
  goneMs: 3000,           // joueur déconnecté : on lance pour lui
  moveMs: 3200,           // le temps de lire ce qui s'est passé
  skipMs: 2200,           // « X passe son tour »
  defiMs: 15000,
  defiRevealMs: 3500,
  podiumMs: 25000,
  defiStep: 3,
  winPoints: 1000,
  perCase: 12,            // les autres : 12 points par case atteinte
});

export const LAST = 63;
export const GEESE = [5, 9, 14, 18, 23, 27, 32, 36, 41, 45, 50, 54, 59];
export const DEFI = [10, 26, 37, 48];
export const BRIDGE = 6, BRIDGE_TO = 12, HOTEL = 19, WELL = 31, MAZE = 42, MAZE_TO = 30, PRISON = 52, DEATH = 58;

const die = () => crypto.randomInt(1, 7);

export class OieGame extends BaseGame {
  static id = 'oie';

  static async create(room, opts, hooks) {
    // Questions des cases Défi (sans base : les cases Défi sont des cases normales)
    let questions = [];
    if (db.enabled()) {
      const rows = await db.quizQuestions(20, [...room.usedQuiz]);
      if (rows) {
        questions = rows.map((r) => {
          const answers = shuffle([r.good, ...r.bad]);
          return { id: r.id, text: r.question, answers, correct: answers.indexOf(r.good) };
        });
      }
    }
    return new OieGame(room, hooks, questions);
  }

  constructor(room, hooks, questions = []) {
    super(room, hooks);
    this.podiumMs = OIE.podiumMs;
    this.questions = questions;
    this.order = shuffle(this.active().map((p) => p.pid));
    this.pos = new Map(this.order.map((pid) => [pid, 0]));
    this.hotel = new Map();     // pid -> tours à passer
    this.stuck = new Map();     // pid -> 'puits' | 'prison'
    this.rolled = new Set();    // a déjà lancé une fois (règle du premier lancer)
    this.turn = -1;
    this.dice = null;
    this.event = null;          // { seq, pid, d, from, to, msgs }
    this.seq = 0;
    this.defi = null;           // { pid, q, answer, ok }
    this.winner = null;
  }

  get current() { return this.order[this.turn] ?? null; }

  start() {
    this.schedule(OIE.introMs, () => this.nextTurn());
  }

  note(pid, extra) {
    this.event = { seq: ++this.seq, pid, ...extra };
  }

  // ---------------------------------------------------------------- tours

  nextTurn() {
    if (this.over || this.winner) return;
    if (!this.order.length) return this.end();
    // Tout le monde bloqué (puits / prison) : on libère tout le monde
    if (this.order.every((pid) => this.stuck.has(pid))) this.stuck.clear();
    this.turn = (this.turn + 1) % this.order.length;
    const pid = this.current;
    this.dice = null;
    this.defi = null;
    const h = this.hotel.get(pid) || 0;
    if (h > 0 || this.stuck.has(pid)) {
      if (h > 0) this.hotel.set(pid, h - 1);
      const why = h > 0 ? `se repose à l’hôtel${h - 1 > 0 ? ' (encore un tour)' : ''}` : (this.stuck.get(pid) === 'puits' ? 'attend au fond du puits' : 'attend en prison');
      this.note(pid, { k: 'skip', msgs: [`${this.name(pid)} ${why}`] });
      this.phase = 'skip';
      this.schedule(OIE.skipMs, () => this.nextTurn());
      return this.changed();
    }
    this.phase = 'turn';
    const p = this.room.players.get(pid);
    this.schedule(p?.connected ? OIE.turnMs : OIE.goneMs, () => this.roll(pid, true));
    this.changed();
  }

  name(pid) { return this.room.players.get(pid)?.name ?? '?'; }

  roll(pid, auto = false) {
    if (this.phase !== 'turn' || pid !== this.current) return;
    const d = [die(), die()];
    this.dice = d;
    const sum = d[0] + d[1];
    const from = this.pos.get(pid);
    const msgs = [];
    const who = this.name(pid);
    if (auto) msgs.push(`⏰ Dés lancés pour ${who}`);
    let to;
    const first = !this.rolled.has(pid);
    this.rolled.add(pid);
    if (first && from === 0 && sum === 9 && (d.includes(6) && d.includes(3))) {
      to = 26;
      msgs.push(`${who} fait 6 et 3 au premier lancer : direct en 26 !`);
    } else if (first && from === 0 && sum === 9 && (d.includes(5) && d.includes(4))) {
      to = 53;
      msgs.push(`${who} fait 5 et 4 au premier lancer : direct en 53 !`);
    } else {
      to = this.advance(from, sum, msgs, who);
    }
    to = this.effects(pid, to, sum, msgs, who);
    this.pos.set(pid, to);
    this.note(pid, { k: 'roll', d, from, to, msgs });

    if (to === LAST) {
      this.winner = pid;
      this.phase = 'move';
      this.changed();
      return this.schedule(OIE.moveMs, () => this.end());
    }
    if (DEFI.includes(to) && this.questions.length) {
      this.phase = 'move';
      this.changed();
      return this.schedule(OIE.moveMs, () => this.askDefi(pid));
    }
    this.phase = 'move';
    this.schedule(OIE.moveMs, () => this.nextTurn());
    this.changed();
  }

  // Avance de n cases ; au-delà de 63 on recule de l'excédent
  advance(from, n, msgs, who) {
    let to = from + n;
    if (to > LAST) {
      to = LAST - (to - LAST);
      msgs.push(`${who} dépasse la 63 et recule en ${to}`);
    } else msgs.push(`${who} avance en ${to}`);
    return to;
  }

  // Effets de la case d'arrivée (les oies s'enchaînent)
  effects(pid, to, sum, msgs, who) {
    for (let guard = 0; guard < 12; guard++) {
      if (GEESE.includes(to)) {
        const next = this.advance(to, sum, [], who);
        msgs.push(`🦢 Une oie ! On rejoue ${sum} : case ${next}`);
        to = next;
        continue;
      }
      if (to === BRIDGE) { msgs.push(`🌉 Le pont : ${who} file en ${BRIDGE_TO}`); to = BRIDGE_TO; continue; }
      if (to === MAZE) { msgs.push(`🌀 Le labyrinthe : retour en ${MAZE_TO}`); to = MAZE_TO; continue; }
      if (to === DEATH) { msgs.push('💀 La mort : retour au départ !'); to = 0; break; }
      if (to === HOTEL) { msgs.push('🏨 L’hôtel : 2 tours de repos'); this.hotel.set(pid, 2); break; }
      if (to === WELL || to === PRISON) {
        const kind = to === WELL ? 'puits' : 'prison';
        // Celui qui y était est délivré, le nouveau prend sa place
        for (const [other, k] of this.stuck) {
          if (other !== pid && k === kind && this.pos.get(other) === to) {
            this.stuck.delete(other);
            msgs.push(`${this.name(other)} est délivré${kind === 'puits' ? ' du puits' : ' de prison'} !`);
          }
        }
        this.stuck.set(pid, kind);
        msgs.push(kind === 'puits' ? '🕳️ Le puits : il faut qu’un autre joueur vienne te sauver' : '🔒 La prison : il faut qu’un autre joueur vienne te libérer');
        break;
      }
      break;
    }
    return to;
  }

  // ---------------------------------------------------------------- défi

  askDefi(pid) {
    const q = this.questions.shift();
    if (!q) return this.nextTurn();
    this.room.usedQuiz?.add(q.id);
    this.defi = { pid, q, answer: null, ok: null };
    this.phase = 'defi';
    const p = this.room.players.get(pid);
    this.schedule(p?.connected ? OIE.defiMs : OIE.goneMs, () => this.defiReveal());
    this.changed();
  }

  defiReveal() {
    if (this.phase !== 'defi' || !this.defi) return;
    const { pid, q, answer } = this.defi;
    const ok = answer === q.correct;
    this.defi.ok = ok;
    const from = this.pos.get(pid);
    const to = Math.max(0, Math.min(LAST - 1, from + (ok ? OIE.defiStep : -OIE.defiStep)));
    this.pos.set(pid, to);
    this.note(pid, {
      k: 'defi', from, to,
      msgs: [ok ? `✅ Bonne réponse ! ${this.name(pid)} avance en ${to}` : `❌ ${answer === null ? 'Pas de réponse' : 'Raté'} : ${this.name(pid)} recule en ${to}`],
    });
    this.phase = 'defi_reveal';
    this.schedule(OIE.defiRevealMs, () => this.nextTurn());
    this.changed();
  }

  // ---------------------------------------------------------------- fin

  end() {
    if (this.phase === 'podium') return;
    for (const pid of this.order) {
      const p = this.pos.get(pid) || 0;
      this.addPoints(pid, pid === this.winner ? OIE.winPoints : p * OIE.perCase);
    }
    this.podium(OIE.podiumMs);
  }

  // ---------------------------------------------------------------- messages

  onMessage(p, m) {
    if (m.t === 'oie_roll') return this.roll(p.pid);
    if (m.t === 'oie_answer') {
      if (this.phase !== 'defi' || this.defi?.pid !== p.pid || this.defi.answer !== null) return;
      if (!Number.isInteger(m.choice) || m.choice < 0 || m.choice >= this.defi.q.answers.length) return;
      this.defi.answer = m.choice;
      this.schedule(500, () => this.defiReveal());
      return this.changed();
    }
    this.hostCommand(p, m, () => {
      // « Faire passer » : on lance (ou on répond) pour le joueur qui traîne
      if (this.phase === 'intro') this.nextTurn();
      else if (this.phase === 'turn') this.roll(this.current, true);
      else if (this.phase === 'defi') this.defiReveal();
    });
  }

  hostCommand(p, m, next) {
    if (m.t === 'game_end' && p.pid === this.room.hostPid && this.phase !== 'podium') { this.end(); return true; }
    return super.hostCommand(p, m, next);
  }

  onPlayerGone(p) {
    if (this.phase === 'turn' && p.pid === this.current) this.schedule(OIE.goneMs, () => this.roll(p.pid, true));
    if (this.phase === 'defi' && this.defi?.pid === p.pid) this.schedule(OIE.goneMs, () => this.defiReveal());
  }

  // ---------------------------------------------------------------- état

  publicState() {
    const s = {
      ...this.base('oie'),
      seq: this.seq,
      players: this.order.map((pid) => ({
        pid, pos: this.pos.get(pid) || 0,
        hotel: this.hotel.get(pid) || 0,
        stuck: this.stuck.get(pid) || null,
      })),
      current: ['turn', 'move', 'defi', 'defi_reveal', 'skip'].includes(this.phase) ? this.current : null,
      dice: this.dice,
      event: this.event,
      winner: this.winner,
    };
    if (this.defi && (this.phase === 'defi' || this.phase === 'defi_reveal')) {
      s.defi = { pid: this.defi.pid, question: this.defi.q.text, choices: this.defi.q.answers, answered: this.defi.answer !== null };
      // La bonne réponse seulement à la révélation
      if (this.phase === 'defi_reveal') Object.assign(s.defi, { correct: this.defi.q.correct, answer: this.defi.answer, ok: this.defi.ok });
    }
    return s;
  }

  playerState(pid) {
    const r = this.ranking().find((x) => x.pid === pid);
    return {
      pid,
      inGame: this.pos.has(pid),
      pos: this.pos.get(pid) ?? null,
      myTurn: this.phase === 'turn' && pid === this.current,
      myDefi: this.phase === 'defi' && this.defi?.pid === pid,
      answer: this.defi?.pid === pid ? this.defi.answer : null,
      score: r?.score ?? 0,
      rank: r?.rank ?? null,
      players: this.ranking().length,
    };
  }
}
