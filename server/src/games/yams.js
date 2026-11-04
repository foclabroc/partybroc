// Yams : 5 dés tirés par le serveur, 13 tours, feuille de marque à 13 cases.
// À son tour : jusqu'à 3 lancers, on garde les dés qu'on veut entre deux lancers,
// puis on remplit une case encore libre (0 si la combinaison n'y est pas).
// Haut : total des 1… des 6, bonus 35 si le haut fait 63 ou plus.
// Bas : Brelan et Carré = total des dés, Full 25, Petite suite 30, Grande suite 40,
// Yams 50, Chance = total des dés. Points de la partie = total de la feuille.
import crypto from 'node:crypto';
import { BaseGame, botMs, fastTimings, shuffle } from './common.js';

export const YMS = fastTimings({
  introMs: 9000,
  goneMs: 3000,           // joueur déconnecté : on joue pour lui
  rollGapMs: 1300,        // pas deux lancers pendant que les dés roulent sur la TV
  scoredMs: 2600,         // « Léa inscrit 25 en Full »
  autoStepMs: 1400,       // joueur qui ne joue pas : un lancer toutes les 1,4 s
  podiumMs: 25000,
  times: [30, 45, 60],    // secondes par tour (option de l'hôte)
  defaultTime: 45,
});

export const CATS = ['1', '2', '3', '4', '5', '6', 'brelan', 'carre', 'full', 'petite', 'grande', 'yams', 'chance'];
export const LABELS = {
  1: 'As', 2: 'Deux', 3: 'Trois', 4: 'Quatre', 5: 'Cinq', 6: 'Six',
  brelan: 'Brelan', carre: 'Carré', full: 'Full', petite: 'Petite suite', grande: 'Grande suite', yams: 'Yams', chance: 'Chance',
};
export const BONUS_AT = 63, BONUS = 35;

export function score(k, dice) {
  const c = [0, 0, 0, 0, 0, 0, 0];
  for (const v of dice) c[v]++;
  const sum = dice.reduce((a, b) => a + b, 0);
  const max = Math.max(...c);
  const has = (s) => s.every((v) => c[v] > 0);
  switch (k) {
    case 'brelan': return max >= 3 ? sum : 0;
    case 'carre': return max >= 4 ? sum : 0;
    case 'full': return c.includes(3) && c.includes(2) ? 25 : 0;
    case 'petite': return has([1, 2, 3, 4]) || has([2, 3, 4, 5]) || has([3, 4, 5, 6]) ? 30 : 0;
    case 'grande': return has([1, 2, 3, 4, 5]) || has([2, 3, 4, 5, 6]) ? 40 : 0;
    case 'yams': return max === 5 ? 50 : 0;
    case 'chance': return sum;
    default: return c[+k] * +k;
  }
}

export function totals(sheet) {
  const up = CATS.slice(0, 6).reduce((a, k) => a + (sheet[k] ?? 0), 0);
  const bonus = up >= BONUS_AT ? BONUS : 0;
  const low = CATS.slice(6).reduce((a, k) => a + (sheet[k] ?? 0), 0);
  return { up, bonus, low, total: up + bonus + low };
}

// Case choisie quand le joueur ne joue pas : la plus rentable, sans gâcher Chance
// ni les petits chiffres ; sinon on raye la case qui coûte le moins.
export function autoPick(sheet, dice) {
  const free = CATS.filter((k) => sheet[k] == null);
  const val = (k) => {
    const s = score(k, dice);
    if (k === 'chance') return s * 0.5;
    if (+k && s < 3 * +k) return s * 0.6;
    return s;
  };
  let pick = free.reduce((a, b) => (val(b) > val(a) ? b : a));
  if (score(pick, dice) === 0) pick = ['1', 'yams', '2', 'grande', 'carre', 'full', '3'].find((k) => free.includes(k)) ?? free[0];
  return pick;
}

// Dés à garder pour le joueur absent : la valeur la plus fréquente
function autoHold(dice) {
  const c = [0, 0, 0, 0, 0, 0, 0];
  for (const v of dice) c[v]++;
  let best = 6;
  for (let v = 6; v >= 1; v--) if (c[v] > c[best]) best = v;
  return dice.map((v) => v === best);
}

// Plan d'un robot après un lancer : quels dés garder, ou s'arrêter et quelle case prendre.
// Malin : vise les suites quand elles sont libres, garde deux paires pour le Full, sinon la
// valeur la plus fréquente (la plus forte à égalité, de préférence une case encore libre).
// Facile : garde toujours la valeur la plus fréquente et s'arrête parfois trop tôt.
export function ymsPlan(sheet, dice, left, level) {
  const free = (k) => sheet[k] == null;
  const c = [0, 0, 0, 0, 0, 0, 0];
  for (const v of dice) c[v]++;
  const pick = () => {
    if (level === 'malin') return autoPick(sheet, dice);
    // Facile : souvent la meilleure case, parfois une autre parmi les 3 meilleures
    if (Math.random() < 0.6) return autoPick(sheet, dice);
    const top = CATS.filter(free).sort((a, b) => score(b, dice) - score(a, dice)).slice(0, 3);
    return top[crypto.randomInt(top.length)];
  };
  const stop = { stop: true, pick: null };
  if (left === 0) return { ...stop, pick: pick() };
  if (free('yams') && score('yams', dice)) return { ...stop, pick: 'yams' };
  if (free('grande') && score('grande', dice)) return { ...stop, pick: 'grande' };
  if (free('full') && score('full', dice)) return { ...stop, pick: 'full' };
  if (level === 'facile' && Math.random() < 0.25) return { ...stop, pick: pick() };
  const keepValues = (vals) => {
    const want = [...vals];
    return dice.map((v) => {
      const i = want.indexOf(v);
      if (i < 0) return false;
      want.splice(i, 1);
      return true;
    });
  };
  if (level === 'malin') {
    // Suites : 4 qui se suivent (petite déjà faite → on tente la grande), ou 3 qui se suivent
    for (const run of [[2, 3, 4, 5], [1, 2, 3, 4], [3, 4, 5, 6]]) {
      if (run.every((v) => c[v]) && free('grande')) return { stop: false, held: keepValues(run) };
    }
    if (free('petite') && score('petite', dice)) return { ...stop, pick: 'petite' };
    if (Math.max(...c) <= 2 && (free('petite') || free('grande'))) {
      for (const run of [[3, 4, 5], [2, 3, 4], [4, 5, 6], [1, 2, 3]]) {
        if (run.every((v) => c[v])) return { stop: false, held: keepValues(run) };
      }
    }
    // Deux paires et Full libre : on garde les deux paires
    const pairs = [1, 2, 3, 4, 5, 6].filter((v) => c[v] === 2);
    if (pairs.length === 2 && free('full')) return { stop: false, held: dice.map((v) => pairs.includes(v)) };
  }
  // La valeur la plus fréquente (Malin : plutôt une valeur dont la case du haut est libre)
  let best = 0;
  let bestScore = -1;
  for (let v = 1; v <= 6; v++) {
    const s = c[v] * 10 + v + (level === 'malin' && free(String(v)) ? 5 : 0);
    if (c[v] && s > bestScore) { best = v; bestScore = s; }
  }
  return { stop: false, held: dice.map((v) => v === best) };
}

const die = () => crypto.randomInt(1, 7);

export class YamsGame extends BaseGame {
  static id = 'yams';

  static async create(room, opts, hooks) {
    return new YamsGame(room, hooks, opts);
  }

  constructor(room, hooks, opts = {}) {
    super(room, hooks);
    this.podiumMs = YMS.podiumMs;
    const secs = YMS.times.includes(opts?.temps) ? opts.temps : YMS.defaultTime;
    this.turnMs = process.env.PB_FAST ? secs * 100 : secs * 1000;
    this.order = shuffle(this.active().map((p) => p.pid));
    this.sheets = new Map(this.order.map((pid) => [pid, {}]));
    this.turn = -1;
    this.round = 1;
    this.dice = [0, 0, 0, 0, 0];
    this.held = [false, false, false, false, false];
    this.left = 3;
    this.rollSeq = 0;           // un lancer de plus : la TV anime les dés
    this.rolled = [];           // index des dés relancés au dernier lancer
    this.lastRoll = 0;
    this.event = null;          // { seq, pid, k, v, auto }
    this.seq = 0;
    this.autoTimer = null;
  }

  get current() { return this.order[this.turn] ?? null; }

  start() {
    this.schedule(YMS.introMs, () => this.nextTurn());
  }

  stop() {
    clearTimeout(this.autoTimer);
    super.stop();
  }

  name(pid) { return this.room.players.get(pid)?.name ?? '?'; }

  nextTurn() {
    if (this.over) return;
    clearTimeout(this.autoTimer);
    if (!this.order.length) return this.end();
    this.turn++;
    if (this.turn >= this.order.length) {
      this.turn = 0;
      this.round++;
    }
    if (this.round > CATS.length) return this.end();
    this.dice = [0, 0, 0, 0, 0];
    this.held = [false, false, false, false, false];
    this.left = 3;
    this.rolled = [];
    this.phase = 'turn';
    const p = this.room.players.get(this.current);
    if (p?.connected) this.schedule(this.turnMs, () => this.autoPlay());
    else this.schedule(YMS.goneMs, () => this.autoPlay());
    this.changed();
  }

  roll(pid) {
    if (this.phase !== 'turn' || pid !== this.current || this.left <= 0) return false;
    if (Date.now() - this.lastRoll < YMS.rollGapMs && this.rollSeq) return false;
    const first = this.left === 3;
    this.rolled = [];
    for (let i = 0; i < 5; i++) {
      if (!first && this.held[i]) continue;
      this.dice[i] = die();
      this.rolled.push(i);
    }
    if (first) this.held = [false, false, false, false, false];
    this.left--;
    this.rollSeq++;
    this.lastRoll = Date.now();
    this.changed();
    return true;
  }

  pick(pid, k, auto = false) {
    if (this.phase !== 'turn' || pid !== this.current || this.left === 3) return;
    const sheet = this.sheets.get(pid);
    if (!CATS.includes(k) || sheet[k] != null) return;
    clearTimeout(this.autoTimer);
    const v = score(k, this.dice);
    sheet[k] = v;
    this.event = { seq: ++this.seq, pid, k, v, auto };
    this.phase = 'scored';
    this.schedule(YMS.scoredMs, () => this.nextTurn());
    this.changed();
  }

  // Le joueur ne joue pas (temps écoulé, déconnecté, « Faire passer ») : on termine son tour
  autoPlay() {
    if (this.phase !== 'turn') return;
    const pid = this.current;
    const step = () => {
      if (this.over || this.phase !== 'turn' || this.current !== pid) return;
      if (this.left === 3) {
        this.lastRoll = 0;
        this.roll(pid);
      } else if (this.left > 0 && this.left < 3 && this.room.players.get(pid)?.connected === false) {
        this.held = autoHold(this.dice);
        this.lastRoll = 0;
        this.roll(pid);
      } else return this.pick(pid, autoPick(this.sheets.get(pid), this.dice), true);
      this.autoTimer = setTimeout(step, YMS.autoStepMs);
    };
    this.deadline = Date.now();
    step();
  }

  end() {
    if (this.phase === 'podium') return;
    clearTimeout(this.autoTimer);
    for (const pid of this.order) this.addPoints(pid, totals(this.sheets.get(pid)).total);
    this.podium(YMS.podiumMs);
  }

  onMessage(p, m) {
    if (m.t === 'yms_roll') return void this.roll(p.pid);
    if (m.t === 'yms_hold') {
      if (this.phase !== 'turn' || p.pid !== this.current || this.left === 3 || this.left === 0) return;
      if (!Number.isInteger(m.i) || m.i < 0 || m.i > 4) return;
      this.held[m.i] = !this.held[m.i];
      return this.changed();
    }
    if (m.t === 'yms_pick') return this.pick(p.pid, String(m.k));
    this.hostCommand(p, m, () => {
      if (this.phase === 'intro') this.nextTurn();
      else if (this.phase === 'turn') this.autoPlay();
      else if (this.phase === 'scored') this.nextTurn();
    });
  }

  hostCommand(p, m, next) {
    if (m.t === 'game_end' && p.pid === this.room.hostPid && this.phase !== 'podium') { this.end(); return true; }
    return super.hostCommand(p, m, next);
  }

  onPlayerGone(p) {
    if (this.phase === 'turn' && p.pid === this.current) this.schedule(YMS.goneMs, () => this.autoPlay());
  }

  // Robot : lance, garde ses dés un par un (on les voit passer dans « Dés gardés »), relance, puis choisit sa case
  botAction(pid, level) {
    if (this.phase !== 'turn' || this.current !== pid) return null;
    if (this.left === 3) return { m: { t: 'yms_roll' }, ms: botMs(1200, 2200) };
    // Laisser les dés finir de rouler sur la TV
    const settle = Math.max(0, YMS.rollGapMs + botMs(300, 700) - (Date.now() - this.lastRoll));
    const plan = this.botMemo(`${pid}:${this.rollSeq}`, () => ymsPlan(this.sheets.get(pid), this.dice, this.left, level));
    if (plan.stop) return { m: { t: 'yms_pick', k: plan.pick }, ms: Math.max(settle, botMs(1000, 1800)) };
    const i = this.held.findIndex((h, j) => h !== plan.held[j]);
    if (i >= 0) return { m: { t: 'yms_hold', i }, ms: Math.max(settle, botMs(450, 800)) };
    return { m: { t: 'yms_roll' }, ms: Math.max(settle, botMs(700, 1200)) };
  }

  publicState() {
    const cur = this.current;
    return {
      ...this.base('yams'),
      round: Math.min(this.round, CATS.length),
      rounds: CATS.length,
      seq: this.seq,
      rollSeq: this.rollSeq,
      rolled: this.rolled,
      current: ['turn', 'scored'].includes(this.phase) ? cur : null,
      dice: this.dice,
      held: this.held,
      left: this.left,
      players: this.order.map((pid) => ({ pid, sheet: this.sheets.get(pid), ...totals(this.sheets.get(pid)) })),
      event: this.event,
    };
  }

  playerState(pid) {
    const r = this.ranking().find((x) => x.pid === pid);
    return {
      pid,
      inGame: this.sheets.has(pid),
      myTurn: this.phase === 'turn' && pid === this.current,
      score: r?.score ?? 0,
      rank: r?.rank ?? null,
      players: this.ranking().length,
    };
  }
}
