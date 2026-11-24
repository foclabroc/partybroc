// Petits chevaux (plateau français) : 4 couleurs (Vert, Jaune, Rouge, Bleu), 2 ou 4 chevaux chacune.
// Parcours de 56 cases (14 par couleur) dans le sens des aiguilles d'une montre, puis un escalier
// de 6 marches jusqu'au centre. Il faut un 6 pour sortir de l'écurie, un 6 fait rejouer (pas plus
// de 2 fois d'affilée), on renvoie à l'écurie le cheval adverse sur lequel on tombe.
// Arrivée « Escalier » (règle française) : s'arrêter pile devant son escalier, puis 1, 2… 6 pour
// chaque marche, et un 6 pour entrer au centre. « Rapide » : on monte avec n'importe quel dé, pile au centre.
// Plus de 4 joueurs : une équipe par couleur, ses membres lancent le dé chacun leur tour.
import crypto from 'node:crypto';
import { BaseGame, botMs, fastTimings, shuffle } from './common.js';

export const CHV = fastTimings({
  introMs: 10000,
  turnMs: 20000,       // pour lancer le dé
  pickMs: 15000,       // pour choisir son cheval
  goneMs: 2500,        // joueur déconnecté : on joue pour lui
  diceMs: 1000,        // le dé roule sur la TV
  stepMs: 260,         // une case
  eatMs: 900,          // le cheval mangé rentre à l'écurie
  readMs: 1300,
  podiumMs: 25000,
  winPoints: 1000,
  perCase: 4,          // les autres : 4 points par case parcourue (tous chevaux)
  ends: ['Escalier', 'Rapide'],
  horses: [2, 4],
  maxSixes: 2,         // rejouer au plus 2 fois d'affilée
});

export const NAMES = ['Vert', 'Jaune', 'Rouge', 'Bleu'];
export const TRACK = 56;
export const START = [0, 14, 28, 42];
export const LAST = 55;   // case devant son escalier
export const END = 62;    // au centre (56-61 : marches 1 à 6)

const die = () => crypto.randomInt(1, 7);

// Case du parcours (0-55) d'un cheval, ou null s'il est à l'écurie, dans l'escalier ou arrivé
export const cellOf = (c, r) => (r >= 0 && r <= LAST ? (START[c] + r) % TRACK : null);

// Couleurs en jeu selon le nombre d'équipes : face à face à 2
export function colorsFor(n) {
  return n <= 1 ? [0] : n === 2 ? [0, 2] : n === 3 ? [0, 1, 2] : [0, 1, 2, 3];
}

export class ChevauxGame extends BaseGame {
  static id = 'chevaux';

  static async create(room, opts, hooks) {
    return new ChevauxGame(room, hooks, opts);
  }

  constructor(room, hooks, opts = {}) {
    super(room, hooks);
    this.podiumMs = CHV.podiumMs;
    this.stairs = (CHV.ends.includes(opts?.arrivee) ? opts.arrivee : CHV.ends[0]) === 'Escalier';
    this.nh = CHV.horses.includes(opts?.chevaux) ? opts.chevaux : 4;
    const pids = shuffle(this.active().map((p) => p.pid));
    this.colors = colorsFor(Math.min(4, pids.length));
    // Équipes : les joueurs répartis dans les couleurs, chacun son tour
    this.teams = this.colors.map(() => []);
    pids.forEach((pid, i) => this.teams[i % this.colors.length].push(pid));
    this.next = this.teams.map(() => 0);       // qui de l'équipe lance la prochaine fois
    this.horses = this.colors.map(() => Array(this.nh).fill(-1));
    this.turn = -1;            // indice dans this.colors
    this.player = null;        // qui lance pour l'équipe en cours
    this.sixes = 0;
    this.again = false;
    this.die = null;
    this.rollSeq = 0;
    this.options = [];
    this.event = null;
    this.seq = 0;
    this.winner = null;        // indice d'équipe
  }

  name(pid) { return this.room.players.get(pid)?.name ?? '?'; }
  teamOf(pid) { return this.teams.findIndex((t) => t.includes(pid)); }
  get color() { return this.colors[this.turn]; }

  start() { this.schedule(CHV.introMs, () => this.nextTurn()); }

  // Membre de l'équipe qui lance : chacun son tour, en sautant les absents s'il y a quelqu'un d'autre
  pickPlayer(t) {
    const team = this.teams[t];
    for (let k = 0; k < team.length; k++) {
      const pid = team[(this.next[t] + k) % team.length];
      if (this.room.players.get(pid)?.connected) {
        this.next[t] = (this.next[t] + k + 1) % team.length;
        return pid;
      }
    }
    const pid = team[this.next[t] % team.length];
    this.next[t] = (this.next[t] + 1) % team.length;
    return pid;
  }

  nextTurn() {
    if (this.over || this.winner !== null) return;
    if (!this.again) {
      this.turn = (this.turn + 1) % this.colors.length;
      this.sixes = 0;
      this.player = this.pickPlayer(this.turn);
    }
    this.again = false;
    this.die = null;
    this.options = [];
    this.phase = 'turn';
    const here = this.room.players.get(this.player)?.connected;
    this.schedule(here ? CHV.turnMs : CHV.goneMs, () => this.roll(this.player, true));
    this.changed();
  }

  // Coups possibles avec le dé d : { h, from, to, eat: {t, h} | null }
  moves(t, d) {
    const c = this.colors[t];
    const out = [];
    const seen = new Set();
    this.horses[t].forEach((r, h) => {
      let to = null;
      if (r < 0) { if (d === 6) to = 0; }
      else if (this.stairs) {
        if (r < LAST) { if (r + d <= LAST) to = r + d; }
        else if (r < END) {
          const step = r - LAST; // 0 = devant l'escalier, 1-6 = marche
          if (step < 6 && d === step + 1) to = r + 1;
          else if (step === 6 && d === 6) to = END;
        }
      } else if (r < END && r + d <= END) to = r + d;
      if (to === null) return;
      // Deux chevaux au même endroit = même coup : on n'en propose qu'un
      const key = `${r}`;
      if (seen.has(key)) return;
      seen.add(key);
      let eat = null;
      const cell = cellOf(c, to);
      if (cell !== null) {
        this.horses.forEach((hs, t2) => {
          if (t2 === t || eat) return;
          hs.forEach((r2, h2) => { if (!eat && cellOf(this.colors[t2], r2) === cell) eat = { t: t2, h: h2 }; });
        });
      }
      out.push({ h, from: r, to, eat });
    });
    return out;
  }

  roll(pid, auto = false) {
    if (this.phase !== 'turn' || pid !== this.player) return;
    const t = this.turn;
    const d = die();
    this.die = d;
    this.rollSeq++;
    if (d === 6) this.sixes++;
    this.options = this.moves(t, d);
    const who = this.name(pid);
    const head = [...(auto ? [`⏰ Dé lancé pour ${who}`] : []), `${who} fait ${d}`];
    if (!this.options.length) {
      head.push(d === 6 ? '🎲 Un 6… mais aucun cheval ne peut bouger' : 'Aucun cheval ne peut bouger');
      this.again = d === 6 && this.sixes <= CHV.maxSixes;
      if (this.again) head.push('🎲 Rejoue !');
      this.event = { seq: ++this.seq, t, pid, d, h: null, path: [], eat: null, msgs: head, wait: CHV.diceMs };
      this.phase = 'move';
      this.schedule(CHV.diceMs + CHV.readMs, () => this.nextTurn());
      this.changed();
      return;
    }
    // Un seul coup possible (ou tous pareils) : on le joue tout de suite
    if (this.options.length === 1) return this.play(this.options[0], head, CHV.diceMs);
    this.phase = 'pick';
    this.pickHead = head;
    const here = this.room.players.get(pid)?.connected;
    this.schedule(here && !auto ? CHV.pickMs : CHV.goneMs, () => this.play(this.best(t, this.options, 'malin'), [...head, `⏰ Cheval choisi pour ${who}`], 0));
    this.changed();
  }

  // Le meilleur coup : manger, sortir, rentrer, sinon faire avancer le plus avancé
  best(t, opts, level) {
    if (level === 'facile') return opts[crypto.randomInt(opts.length)];
    const score = (m) => (m.eat ? 1000 : 0) + (m.to === END ? 800 : 0) + (m.from < 0 ? 600 : 0) + (m.to > LAST ? 300 : 0) + m.to;
    return [...opts].sort((a, b) => score(b) - score(a))[0];
  }

  play(m, head, wait) {
    const t = this.turn;
    const hs = this.horses[t];
    const msgs = [...head];
    const path = m.from < 0 ? [0] : Array.from({ length: m.to - m.from }, (_, i) => m.from + i + 1);
    hs[m.h] = m.to;
    if (m.from < 0) msgs.push(`🐴 Un cheval ${NAMES[this.color].toLowerCase()} sort de l’écurie`);
    if (m.eat) {
      this.horses[m.eat.t][m.eat.h] = -1;
      msgs.push(`💥 Il mange un cheval ${NAMES[this.colors[m.eat.t]].toLowerCase()} : retour à l’écurie !`);
    }
    if (m.to === END) msgs.push('🏆 Un cheval arrive au centre !');
    else if (this.stairs && m.to === LAST) msgs.push('🪜 Pile devant l’escalier !');
    if (hs.every((r) => r === END)) this.winner = t;
    this.again = this.winner === null && this.die === 6 && this.sixes <= CHV.maxSixes;
    if (this.again) msgs.push('🎲 Un 6 : rejoue !');
    this.event = { seq: ++this.seq, t, pid: this.player, d: this.die, h: m.h, from: m.from, path, eat: m.eat, msgs, wait };
    this.options = [];
    this.phase = 'move';
    const ms = wait + path.length * CHV.stepMs + (m.eat ? CHV.eatMs : 0) + CHV.readMs;
    this.schedule(ms, () => (this.winner !== null ? this.end() : this.nextTurn()));
    this.changed();
  }

  pick(pid, h) {
    if (this.phase !== 'pick' || pid !== this.player) return;
    const m = this.options.find((o) => o.h === h);
    if (m) this.play(m, this.pickHead, 0);
  }

  progress(t) { return this.horses[t].reduce((s, r) => s + (r < 0 ? 0 : r + 1), 0); }

  end() {
    if (this.phase === 'podium') return;
    this.teams.forEach((team, t) => {
      const pts = t === this.winner ? CHV.winPoints : this.progress(t) * CHV.perCase;
      for (const pid of team) this.addPoints(pid, pts);
    });
    this.podium(CHV.podiumMs);
  }

  onMessage(p, m) {
    if (m.t === 'chv_roll') return this.roll(p.pid);
    if (m.t === 'chv_pick') return this.pick(p.pid, m.h);
    this.hostCommand(p, m, () => {
      if (this.phase === 'intro') this.nextTurn();
      else if (this.phase === 'turn') this.roll(this.player, true);
      else if (this.phase === 'pick') this.play(this.best(this.turn, this.options, 'malin'), this.pickHead, 0);
    });
  }

  hostCommand(p, m, next) {
    if (m.t === 'game_end' && p.pid === this.room.hostPid && this.phase !== 'podium') { this.end(); return true; }
    return super.hostCommand(p, m, next);
  }

  onPlayerGone(p) {
    if (p.pid !== this.player) return;
    if (this.phase === 'turn') this.schedule(CHV.goneMs, () => this.roll(p.pid, true));
    if (this.phase === 'pick') this.schedule(CHV.goneMs, () => this.play(this.best(this.turn, this.options, 'malin'), this.pickHead, 0));
  }

  botAction(pid, level) {
    if (pid !== this.player) return null;
    if (this.phase === 'turn') return { m: { t: 'chv_roll' }, ms: botMs(1300, 2400) };
    if (this.phase === 'pick') {
      const m = this.botMemo(`chv${this.rollSeq}`, () => this.best(this.turn, this.options, level));
      return { m: { t: 'chv_pick', h: m.h }, ms: botMs(1200, 2200) };
    }
    return null;
  }

  publicState() {
    return {
      ...this.base('chevaux'),
      stairs: this.stairs,
      nh: this.nh,
      seq: this.seq,
      rollSeq: this.rollSeq,
      diceMs: CHV.diceMs,
      stepMs: CHV.stepMs,
      teams: this.colors.map((c, t) => ({ c, pids: this.teams[t], horses: this.horses[t], done: this.horses[t].filter((r) => r === END).length })),
      current: ['turn', 'pick', 'move'].includes(this.phase) ? this.turn : null,
      player: ['turn', 'pick', 'move'].includes(this.phase) ? this.player : null,
      die: this.die,
      options: this.phase === 'pick' ? this.options.map((o) => ({ h: o.h, from: o.from, to: o.to, eat: !!o.eat })) : [],
      event: this.event,
      winner: this.winner,
    };
  }

  playerState(pid) {
    const r = this.ranking().find((x) => x.pid === pid);
    const t = this.teamOf(pid);
    return {
      pid,
      inGame: t >= 0,
      team: t >= 0 ? t : null,
      color: t >= 0 ? this.colors[t] : null,
      mates: t >= 0 ? this.teams[t].filter((x) => x !== pid) : [],
      myTurn: (this.phase === 'turn' || this.phase === 'pick') && pid === this.player,
      score: r?.score ?? 0,
      rank: r?.rank ?? null,
      players: this.ranking().length,
    };
  }
}
