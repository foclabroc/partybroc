// Serpents et échelles : plateau de 100 cases en serpentin, un dé tiré par le serveur.
// Échelle : on monte (bas → haut). Serpent : on redescend (tête → queue).
// Un 6 fait rejouer. Option « Arrivée » : il faut tomber pile sur 100 (sinon on recule
// du surplus) ou il suffit d'atteindre 100.
// Le premier sur la 100 gagne ; les autres sont classés selon leur case.
import crypto from 'node:crypto';
import { BaseGame, botMs, fastTimings, shuffle } from './common.js';

export const SNK = fastTimings({
  introMs: 9000,
  turnMs: 20000,          // temps pour lancer (sinon le dé est lancé tout seul)
  goneMs: 3000,           // joueur déconnecté : on lance pour lui
  stepMs: 280,            // durée d'une case sur la TV (l'appli anime le pion)
  slideMs: 1300,          // montée d'une échelle / descente d'un serpent
  readMs: 1600,           // le temps de lire ce qui s'est passé
  podiumMs: 25000,
  winPoints: 1000,
  perCase: 8,             // les autres : 8 points par case atteinte
  ends: ['Pile sur 100', 'Dès 100'],
  defaultEnd: 'Pile sur 100',
});

export const LAST = 100;
// bas → haut
export const LADDERS = { 4: 25, 8: 30, 13: 46, 33: 49, 42: 63, 50: 69, 62: 81, 74: 92 };
// tête → queue
export const SNAKES = { 27: 5, 40: 3, 43: 18, 54: 31, 66: 45, 76: 58, 89: 53, 99: 41 };

const die = () => crypto.randomInt(1, 7);

export class SerpentsGame extends BaseGame {
  static id = 'serpents';

  static async create(room, opts, hooks) {
    return new SerpentsGame(room, hooks, opts);
  }

  constructor(room, hooks, opts = {}) {
    super(room, hooks);
    this.podiumMs = SNK.podiumMs;
    this.exact = (SNK.ends.includes(opts?.arrivee) ? opts.arrivee : SNK.defaultEnd) === 'Pile sur 100';
    this.order = shuffle(this.active().map((p) => p.pid));
    this.pos = new Map(this.order.map((pid) => [pid, 1]));
    this.turn = -1;
    this.again = false;         // le joueur en cours rejoue (il a fait 6)
    this.die = null;
    this.event = null;          // { seq, pid, d, from, path, to, kind, msgs }
    this.seq = 0;
    this.winner = null;
  }

  get current() { return this.order[this.turn] ?? null; }

  start() {
    this.schedule(SNK.introMs, () => this.nextTurn());
  }

  name(pid) { return this.room.players.get(pid)?.name ?? '?'; }

  nextTurn() {
    if (this.over || this.winner) return;
    if (!this.order.length) return this.end();
    if (!this.again) this.turn = (this.turn + 1) % this.order.length;
    this.again = false;
    this.die = null;
    this.phase = 'turn';
    const p = this.room.players.get(this.current);
    this.schedule(p?.connected ? SNK.turnMs : SNK.goneMs, () => this.roll(this.current, true));
    this.changed();
  }

  // Déplacement de `from` avec le dé `d` : cases traversées (pour l'animation),
  // case d'arrivée avant échelle / serpent, puis case finale.
  move(from, d) {
    const path = [];
    let to = from;
    let bounced = false;
    for (let i = 0; i < d; i++) {
      if (to === LAST) bounced = true;
      to += bounced ? -1 : 1;
      path.push(to);
    }
    if (!this.exact && from + d >= LAST) {
      // « Dès 100 » : on s'arrête sur la 100
      const stop = path.indexOf(LAST);
      path.length = stop + 1;
      to = LAST;
      bounced = false;
    }
    let kind = null;
    let end = to;
    if (LADDERS[to]) { kind = 'ladder'; end = LADDERS[to]; }
    else if (SNAKES[to]) { kind = 'snake'; end = SNAKES[to]; }
    return { path, land: to, bounced, kind, to: end };
  }

  roll(pid, auto = false) {
    if (this.phase !== 'turn' || pid !== this.current) return;
    const d = die();
    this.die = d;
    const from = this.pos.get(pid);
    const mv = this.move(from, d);
    const who = this.name(pid);
    const msgs = [];
    if (auto) msgs.push(`⏰ Dé lancé pour ${who}`);
    msgs.push(`${who} fait ${d}`);
    if (mv.bounced) msgs.push(`🎯 Il fallait tomber pile : retour en ${mv.land}`);
    if (mv.kind === 'ladder') msgs.push(`🪜 Une échelle ! ${who} monte de ${mv.land} à ${mv.to}`);
    if (mv.kind === 'snake') msgs.push(`🐍 Aïe ! ${who} glisse de ${mv.land} à ${mv.to}`);
    this.pos.set(pid, mv.to);
    if (mv.to === LAST) this.winner = pid;
    else if (d === 6) {
      this.again = true;
      msgs.push('🎲 Un 6 : rejoue !');
    }
    this.event = { seq: ++this.seq, pid, d, from, path: mv.path, land: mv.land, to: mv.to, kind: mv.kind, msgs };
    this.phase = 'move';
    const ms = mv.path.length * SNK.stepMs + (mv.kind ? SNK.slideMs : 0) + SNK.readMs;
    this.schedule(ms, () => (this.winner ? this.end() : this.nextTurn()));
    this.changed();
  }

  end() {
    if (this.phase === 'podium') return;
    for (const pid of this.order) {
      const p = this.pos.get(pid) || 1;
      this.addPoints(pid, pid === this.winner ? SNK.winPoints : p * SNK.perCase);
    }
    this.podium(SNK.podiumMs);
  }

  onMessage(p, m) {
    if (m.t === 'snk_roll') return this.roll(p.pid);
    this.hostCommand(p, m, () => {
      if (this.phase === 'intro') this.nextTurn();
      else if (this.phase === 'turn') this.roll(this.current, true);
    });
  }

  hostCommand(p, m, next) {
    if (m.t === 'game_end' && p.pid === this.room.hostPid && this.phase !== 'podium') { this.end(); return true; }
    return super.hostCommand(p, m, next);
  }

  onPlayerGone(p) {
    if (this.phase === 'turn' && p.pid === this.current) this.schedule(SNK.goneMs, () => this.roll(p.pid, true));
  }

  // Robot : lance le dé à son tour
  botAction(pid) {
    if (this.phase === 'turn' && this.current === pid) return { m: { t: 'snk_roll' }, ms: botMs(1400, 2600) };
    return null;
  }

  publicState() {
    return {
      ...this.base('serpents'),
      seq: this.seq,
      exact: this.exact,
      stepMs: SNK.stepMs,
      slideMs: SNK.slideMs,
      players: this.order.map((pid) => ({ pid, pos: this.pos.get(pid) || 1 })),
      current: ['turn', 'move'].includes(this.phase) ? this.current : null,
      die: this.die,
      event: this.event,
      winner: this.winner,
    };
  }

  playerState(pid) {
    const r = this.ranking().find((x) => x.pid === pid);
    return {
      pid,
      inGame: this.pos.has(pid),
      pos: this.pos.get(pid) ?? null,
      myTurn: this.phase === 'turn' && pid === this.current,
      score: r?.score ?? 0,
      rank: r?.rank ?? null,
      players: this.ranking().length,
    };
  }
}
