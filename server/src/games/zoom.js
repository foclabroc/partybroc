// Zoom mystère : un emoji énorme, très zoomé, qui se dézoome petit à petit.
// Un seul essai parmi 4 noms : plus on trouve tôt, plus on marque.
import { fastTimings, shuffle } from './common.js';
import { RoundGame } from './round.js';
import { EMOJI_FAMILIES, ALL_EMOJIS, photoOf } from './emojis.js';

export const ZOOM = fastTimings({
  rounds: [6, 10, 15],
  defaultRounds: 10,
  introMs: 5000,
  askMs: 20000,
  revealMs: 5000,
  podiumMs: 25000,
  minPoints: 100,
  speedPoints: 900,
});

export class ZoomGame extends RoundGame {
  static id = 'zoom';

  static async create(room, opts, hooks) {
    return new ZoomGame(room, hooks, opts);
  }

  constructor(room, hooks, opts) {
    const count = ZOOM.rounds.includes(opts?.rounds) ? opts.rounds : ZOOM.defaultRounds;
    super(room, hooks, { id: 'zoom', count, answerType: 'zoom_pick', ...ZOOM });
    // Pas deux fois le même emoji dans la soirée (tant qu'il en reste)
    room.used.zoom ??= new Set();
    let pool = ALL_EMOJIS.filter((x) => !room.used.zoom.has(x.e));
    if (pool.length < count) { room.used.zoom.clear(); pool = [...ALL_EMOJIS]; }
    this.items = shuffle(pool).slice(0, count);
    for (const x of this.items) room.used.zoom.add(x.e);
  }

  makeRound(i) {
    const it = this.items[i];
    const others = shuffle(EMOJI_FAMILIES[it.family].filter(([e]) => e !== it.e)).slice(0, 3).map(([, n]) => n);
    const choices = shuffle([it.name, ...others]);
    return {
      e: it.e,
      choices,
      correct: choices.indexOf(it.name),
      // point du zoom : jamais pile au centre
      fx: 0.25 + Math.random() * 0.5,
      fy: 0.25 + Math.random() * 0.5,
    };
  }

  accept(p, m) {
    return Number.isInteger(m.choice) && m.choice >= 0 && m.choice < 4 ? m.choice : undefined;
  }

  scoreRound() {
    for (const [pid, a] of this.answers) {
      if (a.v === this.round.correct) this.addPoints(pid, ZOOM.minPoints + Math.round((ZOOM.speedPoints * this.speed(a.at)) / 10) * 10);
    }
  }

  publicRound(reveal) {
    // L'image elle-même est l'énigme (affichée sur la TV) ; le bon nom n'est envoyé qu'à la fin
    // img : photo réelle (identifiant opaque), sinon l'appli dessine l'emoji
    const s = { e: this.round.e, img: photoOf(this.round.e), choices: this.round.choices, fx: this.round.fx, fy: this.round.fy };
    if (reveal) {
      s.correct = this.round.correct;
      s.picks = Object.fromEntries([...this.answers].map(([pid, a]) => [pid, a.v]));
    }
    return s;
  }
}
