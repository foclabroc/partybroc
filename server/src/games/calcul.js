// Course de calcul : un calcul s'affiche, on tape le résultat. Juste et rapide = beaucoup de points.
// Les calculs sont fabriqués par le serveur (pas de contenu en base), de plus en plus durs.
import crypto from 'node:crypto';
import { fastTimings } from './common.js';
import { RoundGame } from './round.js';

export const CALC = fastTimings({
  rounds: [10, 15, 20],
  defaultRounds: 10,
  levels: ['Facile', 'Moyen', 'Difficile'],
  defaultLevel: 'Moyen',
  introMs: 5000,
  askMs: 15000,
  revealMs: 4500,
  podiumMs: 25000,
  basePoints: 300,
  speedPoints: 700,
  firstBonus: 100,
});

const rnd = (a, b) => a + crypto.randomInt(b - a + 1);
const pick = (l) => l[crypto.randomInt(l.length)];

// Un calcul : texte affiché + résultat (entier)
export function makeCalc(level, step) {
  // step : 0 → 1 au fil de la partie (un peu plus dur à la fin)
  const hard = step > 0.6;
  if (level === 'Facile') {
    const k = pick(hard ? ['+', '-', '×', '+10'] : ['+', '-', '+', '×']);
    if (k === '+') { const a = rnd(1, hard ? 30 : 15), b = rnd(1, hard ? 20 : 10); return { text: `${a} + ${b}`, value: a + b }; }
    if (k === '-') { const a = rnd(5, hard ? 30 : 20), b = rnd(1, a - 1); return { text: `${a} − ${b}`, value: a - b }; }
    if (k === '+10') { const a = rnd(11, 59), b = pick([10, 20, 30]); return { text: `${a} + ${b}`, value: a + b }; }
    const a = rnd(2, 5), b = rnd(1, 10); return { text: `${a} × ${b}`, value: a * b };
  }
  if (level === 'Moyen') {
    const k = pick(hard ? ['×', '÷', '+-', '×+', '+'] : ['+', '-', '×', '÷']);
    if (k === '+') { const a = rnd(15, 99), b = rnd(11, 99); return { text: `${a} + ${b}`, value: a + b }; }
    if (k === '-') { const a = rnd(40, 150), b = rnd(11, a - 5); return { text: `${a} − ${b}`, value: a - b }; }
    if (k === '×') { const a = rnd(3, 12), b = rnd(3, 12); return { text: `${a} × ${b}`, value: a * b }; }
    if (k === '÷') { const b = rnd(2, 10), v = rnd(2, 12); return { text: `${b * v} ÷ ${b}`, value: v }; }
    if (k === '+-') { const a = rnd(20, 80), b = rnd(10, 50), c = rnd(5, 30); return { text: `${a} + ${b} − ${c}`, value: a + b - c }; }
    const a = rnd(2, 9), b = rnd(2, 9), c = rnd(1, 20); return { text: `${a} × ${b} + ${c}`, value: a * b + c };
  }
  // Difficile
  const k = pick(hard ? ['2x1', '()', 'pct', 'sq', '2x2'] : ['2x1', '()', 'pct', 'sq', '÷']);
  if (k === '2x1') { const a = rnd(12, 99), b = rnd(3, 9); return { text: `${a} × ${b}`, value: a * b }; }
  if (k === '()') { const a = rnd(3, 25), b = rnd(2, 20), c = rnd(2, 9); return { text: `(${a} + ${b}) × ${c}`, value: (a + b) * c }; }
  if (k === 'pct') {
    const p = pick([10, 20, 25, 50, 75]);
    const base = p === 25 || p === 75 ? rnd(2, 40) * 4 : rnd(2, 50) * 10;
    return { text: `${p} % de ${base}`, value: (base * p) / 100 };
  }
  if (k === 'sq') { const a = rnd(11, 25); return { text: `${a}²`, value: a * a }; }
  if (k === '÷') { const b = rnd(3, 15), v = rnd(6, 25); return { text: `${b * v} ÷ ${b}`, value: v }; }
  const a = rnd(11, 30), b = rnd(11, 19); return { text: `${a} × ${b}`, value: a * b };
}

export class CalculGame extends RoundGame {
  static id = 'calcul';

  static async create(room, opts, hooks) {
    return new CalculGame(room, hooks, opts);
  }

  constructor(room, hooks, opts) {
    const count = CALC.rounds.includes(opts?.rounds) ? opts.rounds : CALC.defaultRounds;
    super(room, hooks, { id: 'calcul', count, answerType: 'calc_answer', ...CALC });
    this.level = CALC.levels.includes(opts?.level) ? opts.level : CALC.defaultLevel;
    this.first = null;
  }

  makeRound(i) {
    return makeCalc(this.level, this.count > 1 ? i / (this.count - 1) : 0);
  }

  accept(p, m) {
    const v = Number(m.v);
    if (!Number.isInteger(v) || Math.abs(v) > 1e6) return undefined;
    return v;
  }

  scoreRound() {
    const good = [...this.answers].filter(([, a]) => a.v === this.round.value).sort((x, y) => x[1].at - y[1].at);
    this.first = good[0]?.[0] ?? null;
    for (const [pid, a] of good) {
      this.addPoints(pid, CALC.basePoints + Math.round((CALC.speedPoints * this.speed(a.at)) / 10) * 10 + (pid === this.first ? CALC.firstBonus : 0));
    }
  }

  publicRound(reveal) {
    const s = { expr: this.round.text, level: this.level };
    if (reveal) {
      s.value = this.round.value;
      s.first = this.first;
      // temps de chaque bonne réponse (en secondes) pour l'affichage
      s.good = [...this.answers].filter(([, a]) => a.v === this.round.value)
        .map(([pid, a]) => ({ pid, ms: a.at - this.askStart })).sort((a, b) => a.ms - b.ms);
    }
    return s;
  }
}
