// Mémoire : la TV montre une grille d'emojis sur des cases de couleur pendant 10 s,
// puis la cache et pose une question (combien de…, qu'y avait-il en haut à gauche…).
// La grille n'est JAMAIS envoyée pendant la question (les téléphones reçoivent l'état aussi).
import crypto from 'node:crypto';
import { fastTimings, shuffle } from './common.js';
import { RoundGame } from './round.js';
import { ALL_EMOJIS, photoOf, nameOfEmoji } from './emojis.js';

export const MEM = fastTimings({
  rounds: [5, 8, 12],
  defaultRounds: 8,
  introMs: 5000,
  showMs: 10000,
  askMs: 15000,
  revealMs: 6000,
  podiumMs: 25000,
  basePoints: 500,
  speedPoints: 300,
  cols: 4,
  rows: 3,
});

export const COLORS = ['rouge', 'bleu', 'vert', 'jaune', 'violet', 'orange'];
const CORNERS = [['en haut à gauche', 0], ['en haut à droite', 3], ['en bas à gauche', 8], ['en bas à droite', 11]];
const rnd = (n) => crypto.randomInt(n);
// Nom d'un emoji, pour l'animateur vocal (« Combien y avait-il de Chat ? »)
const nameOf = (e) => ALL_EMOJIS.find((x) => x.e === e)?.name.toLowerCase() ?? 'cet objet';

// Dans le texte d'une question : le nom si la grille montre des photos (« Chien »), sinon l'emoji
const label = (e) => (photoOf(e) ? `« ${nameOfEmoji(e)} »` : e);

// Une grille : 12 cases, 5 ou 6 emojis différents, certains en plusieurs exemplaires
export function makeScene() {
  const kinds = shuffle([...ALL_EMOJIS]).slice(0, 5 + rnd(2)).map((x) => x.e);
  const cells = [...kinds];
  while (cells.length < MEM.cols * MEM.rows) cells.push(kinds[rnd(kinds.length)]);
  return shuffle(cells).map((e) => ({ e, c: COLORS[rnd(COLORS.length)] }));
}

// Une question sur la grille : { text, kind, choices, correct }
export function makeQuestion(cells) {
  const count = (e) => cells.filter((x) => x.e === e).length;
  const kinds = [...new Set(cells.map((x) => x.e))];
  const types = ['count', 'corner', 'absent'];
  if (kinds.some((e) => count(e) === 1)) types.push('color', 'color');
  const type = types[rnd(types.length)];

  if (type === 'count') {
    const e = kinds[rnd(kinds.length)];
    const n = count(e);
    const set = new Set([n]);
    for (const d of shuffle([-1, 1, 2, -2, 3])) if (set.size < 4 && n + d >= 0) set.add(n + d);
    const choices = shuffle([...set].map(String));
    return { text: `Combien y avait-il de ${label(e)} ?`, say: `Combien y avait-il de : ${nameOf(e)} ?`, kind: 'number', choices, correct: choices.indexOf(String(n)) };
  }
  if (type === 'corner') {
    const [label, idx] = CORNERS[rnd(4)];
    const e = cells[idx].e;
    const others = shuffle([...kinds.filter((x) => x !== e), ...shuffle([...ALL_EMOJIS]).map((x) => x.e).filter((x) => !kinds.includes(x)).slice(0, 2)]).slice(0, 3);
    const choices = shuffle([e, ...others]);
    return { text: `Qu’y avait-il ${label} ?`, kind: 'emoji', choices, correct: choices.indexOf(e) };
  }
  if (type === 'color') {
    const singles = kinds.filter((e) => count(e) === 1);
    const e = singles[rnd(singles.length)];
    const c = cells.find((x) => x.e === e).c;
    const choices = shuffle([c, ...shuffle(COLORS.filter((x) => x !== c)).slice(0, 3)]);
    return { text: `De quelle couleur était la case ${label(e)} ?`, say: `De quelle couleur était la case : ${nameOf(e)} ?`, kind: 'color', choices, correct: choices.indexOf(c) };
  }
  // absent : 3 emojis de la grille + 1 qui n'y était pas
  const absent = shuffle([...ALL_EMOJIS]).map((x) => x.e).find((x) => !kinds.includes(x));
  const choices = shuffle([absent, ...shuffle([...kinds]).slice(0, 3)]);
  return { text: 'Lequel n’était PAS sur l’image ?', kind: 'emoji', choices, correct: choices.indexOf(absent) };
}

export class MemoireGame extends RoundGame {
  static id = 'memoire';

  static async create(room, opts, hooks) {
    return new MemoireGame(room, hooks, opts);
  }

  constructor(room, hooks, opts) {
    const count = MEM.rounds.includes(opts?.rounds) ? opts.rounds : MEM.defaultRounds;
    super(room, hooks, { id: 'memoire', count, answerType: 'mem_pick', ...MEM });
  }

  makeRound() {
    const cells = makeScene();
    return { cells, q: makeQuestion(cells) };
  }

  accept(p, m) {
    return Number.isInteger(m.choice) && m.choice >= 0 && m.choice < this.round.q.choices.length ? m.choice : undefined;
  }

  scoreRound() {
    for (const [pid, a] of this.answers) {
      if (a.v === this.round.q.correct) this.addPoints(pid, MEM.basePoints + Math.round((MEM.speedPoints * this.speed(a.at)) / 10) * 10);
    }
  }

  publicRound(reveal) {
    const { cells, q } = this.round;
    const s = { cols: MEM.cols };
    // i : photo réelle de chaque case / de chaque choix (sinon l'appli affiche l'emoji)
    if (this.phase === 'show' || reveal) s.cells = cells.map((x) => ({ ...x, i: photoOf(x.e) }));
    if (this.phase !== 'show') {
      Object.assign(s, { question: q.text, say: q.say || q.text, kind: q.kind, choices: q.choices });
      if (q.kind === 'emoji') s.imgs = q.choices.map((e) => photoOf(e));
    }
    if (reveal) {
      s.correct = q.correct;
      s.picks = Object.fromEntries([...this.answers].map(([pid, a]) => [pid, a.v]));
    }
    return s;
  }
}
