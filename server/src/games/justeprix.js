// Le juste prix : un objet du quotidien, chacun tape son prix. Le plus proche gagne.
// Prix moyens indicatifs (en euros) dans pb_jp_items, jamais envoyés avant la révélation.
import { db } from '../db.js';
import { fastTimings, loadContent } from './common.js';
import { RoundGame } from './round.js';
import { imgId, slug } from '../images.js';

// Photo du produit : server/images/justeprix/<nom sans l'article>.jpg (« Un jean » → jean.jpg)
const photoOfItem = (name) => imgId(`justeprix/${slug(String(name).replace(/^(une?|des|le|la|les) /i, ''))}`);

export const JP = fastTimings({
  rounds: [5, 8, 12],
  defaultRounds: 8,
  introMs: 6000,
  askMs: 25000,
  revealMs: 8000,
  podiumMs: 25000,
  rankPoints: [500, 300, 200, 100],  // 1er, 2e, 3e, 4e plus proches
  closeBonus: 200,                   // à moins de 10 %
  exactBonus: 500,                   // à moins de 2 % : « Le juste prix ! »
});

export class JustePrixGame extends RoundGame {
  static id = 'justeprix';

  static async create(room, opts, hooks) {
    const n = JP.rounds.includes(opts?.rounds) ? opts.rounds : JP.defaultRounds;
    const rows = await loadContent(db, room, 'pb_jp_items', 'emoji, name, detail, price', n, 'Aucun objet du Juste prix en base');
    return new JustePrixGame(room, hooks, rows);
  }

  constructor(room, hooks, rows) {
    super(room, hooks, { id: 'justeprix', count: rows.length, answerType: 'jp_guess', ...JP });
    this.items = rows.map((r) => ({ ...r, price: Number(r.price) }));
    this.guessList = [];
  }

  makeRound(i) { return this.items[i]; }

  accept(p, m) {
    const v = typeof m.v === 'number' ? m.v : Number(String(m.v ?? '').replace(',', '.'));
    if (!Number.isFinite(v) || v < 0 || v > 1e7) return undefined;
    return Math.round(v * 100) / 100;
  }

  scoreRound() {
    const price = this.round.price;
    const list = [...this.answers].map(([pid, a]) => ({ pid, v: a.v, diff: Math.abs(a.v - price), pct: price > 0 ? Math.abs(a.v - price) / price : 0 }))
      .sort((a, b) => a.diff - b.diff);
    // ex aequo : même rang, mêmes points
    let rank = 0, prev = null;
    list.forEach((r, i) => { if (r.diff !== prev) { rank = i; prev = r.diff; } r.rank = rank; });
    for (const r of list) {
      let pts = JP.rankPoints[r.rank] ?? 0;
      if (r.pct <= 0.02) { pts += JP.exactBonus; r.exact = true; } else if (r.pct <= 0.1) pts += JP.closeBonus;
      if (pts) this.addPoints(r.pid, pts);
    }
    this.guessList = list;
  }

  playerRound(pid) {
    return { exact: this.phase === 'reveal' && !!this.guessList.find((r) => r.pid === pid)?.exact };
  }

  publicRound(reveal) {
    const { emoji, name, detail } = this.round;
    const s = { emoji, img: photoOfItem(name), name, detail };
    if (reveal) {
      s.price = this.round.price;
      s.guesses = this.guessList.map(({ pid, v, rank, exact }) => ({ pid, v, rank, exact: !!exact }));
    }
    return s;
  }
}
