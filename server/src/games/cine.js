// Quiz cinéma : une scène d'un film (TMDB) en grand sur la TV, chacun choisit le titre parmi 4
// sur son téléphone (les choix ne sont PAS sur la TV). Indice en option à 10 s de la fin :
// l'année et le genre ; une bonne réponse après l'indice rapporte moins.
// Phases : intro → load (l'image se charge sur la TV) → ask → reveal → … → podium.
import { fastTimings, shuffle, BaseGame } from './common.js';
import { CINE_CATEGORIES, loadFilms, filmScene } from '../tmdb.js';
import { fold } from '../deezer.js';

export const CINE = fastTimings({
  rounds: [10, 15, 20],
  defaultRounds: 10,
  times: ['15 s', '20 s', '30 s'],
  defaultTime: '20 s',
  introMs: 7000,
  loadMs: 1800,
  waitMs: 7000,
  hintBeforeEndMs: 10000,
  revealMs: 7000,
  podiumMs: 25000,
  basePoints: 500,
  speedPoints: 500,
  hintPoints: 250, // bonne réponse après l'indice
});
export const CINE_CHOICES = [...CINE_CATEGORIES.map((c) => c.name), 'Mélange'];
export const CINE_HINTS = ['Avec', 'Sans'];

const askMs = (v) => {
  const s = parseInt(String(v), 10);
  return fastTimings({ askMs: ([15, 20, 30].includes(s) ? s : 20) * 1000 }).askMs;
};

// 3 faux titres : même catégorie, époque proche, pas de titre trop ressemblant (« Shrek » / « Shrek 2 »)
export function wrongTitles(film, pool) {
  const good = fold(film.title);
  const head = (t) => fold(t).split(' ').slice(0, 2).join(' ');
  const seen = new Set([good]);
  const near = shuffle(pool.filter((f) => f.id !== film.id))
    .sort((a, b) => (a.group === film.group ? 0 : 1) - (b.group === film.group ? 0 : 1)
      || Math.abs((a.year ?? 0) - (film.year ?? 0)) / 6 - Math.abs((b.year ?? 0) - (film.year ?? 0)) / 6);
  const out = [];
  for (const f of near) {
    const t = fold(f.title);
    if (!t || seen.has(t) || [...seen].some((x) => t.startsWith(x) || x.startsWith(t) || head(f.title) === head(film.title))) continue;
    seen.add(t);
    out.push(f.title);
    if (out.length === 3) break;
  }
  return out;
}

export class CineGame extends BaseGame {
  static id = 'cine';

  static async create(room, opts, hooks) {
    const n = CINE.rounds.includes(opts?.rounds) ? opts.rounds : CINE.defaultRounds;
    const name = CINE_CHOICES.includes(opts?.categorie) ? opts.categorie : CINE_CHOICES[0];
    const cats = name === 'Mélange' ? CINE_CATEGORIES : CINE_CATEGORIES.filter((c) => c.name === name);
    const lists = await Promise.allSettled(cats.map((c) => loadFilms(c)));
    const seen = new Set();
    const pool = [];
    for (const f of lists.filter((r) => r.status === 'fulfilled').flatMap((r) => r.value)) {
      if (!seen.has(f.id)) { seen.add(f.id); pool.push(f); }
    }
    if (pool.length < 8) {
      const err = lists.find((r) => r.status === 'rejected')?.reason;
      throw new Error(err?.message || 'TMDB ne répond pas, réessaie dans un instant');
    }
    room.used.cine ??= new Set();
    let fresh = pool.filter((f) => !room.used.cine.has(f.id));
    if (fresh.length < n + 3) { room.used.cine.clear(); fresh = pool; }
    return new CineGame(room, hooks, {
      name, pool, picks: shuffle([...fresh]), count: Math.min(n, fresh.length),
      ask: askMs(opts?.temps), hint: opts?.indice !== 'Sans',
    });
  }

  constructor(room, hooks, { name, pool, picks, count, ask, hint }) {
    super(room, hooks);
    this.category = name;
    this.pool = pool;
    this.picks = picks;
    this.next_ = 0;
    this.count = count;
    this.askMs = ask;
    this.withHint = hint;
    this.podiumMs = CINE.podiumMs;
    this.index = -1;
    this.round = null;
    this.answers = new Map(); // pid -> { v, at }
    this.pending = null;
    this.askStart = 0;
    this.hintShown = false;
    this.loading = 0;
  }

  start() {
    this.pending = this.prepare();
    this.schedule(CINE.introMs, () => this.next());
  }

  async prepare() {
    while (this.next_ < this.picks.length) {
      const film = this.picks[this.next_++];
      const wrong = wrongTitles(film, this.pool);
      if (wrong.length < 3) continue;
      const scene = await filmScene(film);
      if (this.over) return null;
      const choices = shuffle([film.title, ...wrong]);
      return { film, ...scene, choices, correct: choices.indexOf(film.title) };
    }
    return null;
  }

  isLast() { return this.index >= this.count - 1; }

  next() {
    if (this.over || this.phase === 'load') return;
    if (this.isLast()) return this.podium(this.podiumMs);
    this.index++;
    this.answers.clear();
    this.gains.clear();
    this.round = null;
    this.hintShown = false;
    this.phase = 'load';
    const seq = ++this.loading;
    this.schedule(CINE.waitMs, () => this.giveUp(seq));
    this.changed();
    const started = Date.now();
    Promise.resolve(this.pending || this.prepare()).then((r) => {
      if (this.over || seq !== this.loading || this.phase !== 'load') return;
      this.pending = null;
      if (!r) return this.giveUp(seq);
      this.round = r;
      this.room.used.cine?.add(r.film.id);
      this.schedule(Math.max(CINE.loadMs - (Date.now() - started), Math.round(CINE.loadMs / 2)), () => this.ask());
      this.changed();
    }).catch((e) => { console.error('[cine]', e); this.giveUp(seq); });
  }

  giveUp(seq) {
    if (this.over || seq !== this.loading || this.phase !== 'load' || this.round) return;
    this.loading++;
    this.count = Math.max(0, this.index);
    this.index--;
    console.error('[cine] image introuvable, fin de la partie');
    this.podium(this.podiumMs);
  }

  ask() {
    if (this.phase !== 'load' || !this.round) return;
    this.phase = 'ask';
    this.askStart = Date.now();
    this.schedule(this.askMs, () => this.reveal());
    // L'indice : un minuteur à part (le minuteur principal reste celui de la question)
    if (this.withHint && this.askMs > CINE.hintBeforeEndMs) {
      const idx = this.index;
      setTimeout(() => {
        if (this.over || this.phase !== 'ask' || this.index !== idx) return;
        this.hintShown = true;
        this.changed();
      }, this.askMs - CINE.hintBeforeEndMs);
    }
    this.changed();
  }

  reveal() {
    if (this.phase !== 'ask') return;
    this.phase = 'reveal';
    const hintAt = this.withHint ? this.askStart + this.askMs - CINE.hintBeforeEndMs : Infinity;
    for (const [pid, a] of this.answers) {
      if (a.v !== this.round.correct) continue;
      const pts = a.at >= hintAt
        ? CINE.hintPoints
        : CINE.basePoints + Math.round((CINE.speedPoints * Math.max(0, 1 - (a.at - this.askStart) / this.askMs)) / 10) * 10;
      this.addPoints(pid, pts);
    }
    if (!this.isLast()) this.pending = this.prepare();
    this.schedule(CINE.revealMs, () => (this.isLast() ? this.podium(this.podiumMs) : this.next()));
    this.changed();
  }

  checkAll() {
    const need = this.active();
    if (this.phase === 'ask' && need.length && need.every((p) => this.answers.has(p.pid))) this.schedule(700, () => this.reveal());
  }

  onMessage(p, m) {
    if (m.t === 'cine_pick') {
      if (this.phase !== 'ask' || m.r !== this.index || this.answers.has(p.pid)) return;
      if (!Number.isInteger(m.choice) || m.choice < 0 || m.choice > 3 || !this.room.players.has(p.pid)) return;
      this.answers.set(p.pid, { v: m.choice, at: Date.now() });
      this.onPlayerJoin(p);
      this.checkAll();
      this.changed();
      return;
    }
    this.hostCommand(p, m, () => {
      if (this.phase === 'intro') this.next();
      else if (this.phase === 'ask') this.reveal();
      else if (this.phase === 'reveal') (this.isLast() ? this.podium(this.podiumMs) : this.next());
    });
  }

  onPlayerGone() { this.checkAll(); }

  publicState() {
    const s = { ...this.base('cine'), index: this.index, count: this.count, category: this.category, withHint: this.withHint };
    const r = this.round;
    if (r && ['load', 'ask', 'reveal'].includes(this.phase)) s.image = r.image;
    if (r && (this.phase === 'ask' || this.phase === 'reveal')) {
      s.choices = r.choices; // affichés seulement sur les téléphones
      s.answered = [...this.answers.keys()];
      if (this.hintShown || this.phase === 'reveal') s.hint = [r.film.year, ...r.film.genres].filter(Boolean).join(' · ');
    }
    if (r && this.phase === 'reveal') {
      Object.assign(s, { correct: r.correct, title: r.film.title, year: r.film.year, director: r.director, poster: r.film.poster });
      s.picks = Object.fromEntries([...this.answers].map(([pid, a]) => [pid, a.v]));
    }
    return s;
  }

  playerState(pid) {
    const r = this.ranking().find((x) => x.pid === pid);
    return {
      answer: this.answers.get(pid)?.v ?? null,
      gain: this.phase === 'reveal' ? (this.gains.get(pid) || 0) : null,
      score: r?.score ?? 0,
      rank: r?.rank ?? null,
      players: this.ranking().length,
    };
  }
}
