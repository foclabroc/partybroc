// Dessin à deviner : chacun son tour, un joueur choisit un mot et le dessine sur
// son téléphone ; le dessin s'affiche en direct sur la TV et les autres devinent.
// Les traits passent par des messages directs (pas par l'état du salon).
import crypto from 'node:crypto';
import { db } from '../db.js';
import { BaseGame, cleanText, fastTimings, fold, levenshtein, loadContent, shuffle } from './common.js';

export const DSN = fastTimings({
  turns: [1, 2],
  defaultTurns: 1,
  introMs: 6000,
  chooseMs: 12000,
  drawMs: 80000,
  revealMs: 7000,
  podiumMs: 25000,
  findBase: 100,
  findSpeed: 400,       // + jusqu'à 400 selon la rapidité
  firstBonus: 50,
  drawerPerFind: 100,
  maxStrokes: 400,
  maxPointsPerStroke: 3000,
  maxWidth: 60,
  colors: 12,
  feedSize: 8,
});

export class DessinGame extends BaseGame {
  static id = 'dessin';

  static async create(room, opts, hooks) {
    const turns = DSN.turns.includes(opts?.turns) ? opts.turns : DSN.defaultTurns;
    const order = [];
    for (let t = 0; t < turns; t++) order.push(...shuffle([...room.players.values()].filter((p) => p.connected).map((p) => p.pid)));
    // 3 mots proposés par tour
    const rows = await loadContent(db, room, 'pb_dessin_words', 'word, difficulty', order.length * 3, 'Aucun mot à dessiner en base');
    return new DessinGame(room, order, rows, hooks);
  }

  constructor(room, order, rows, hooks) {
    super(room, hooks);
    this.order = order;
    this.pool = rows.map((r) => ({ word: r.word, difficulty: r.difficulty }));
    this.turn = -1;
    this.drawer = null;
    this.choices = [];
    this.word = null;
    this.found = new Map();   // pid -> ordre d'arrivée
    this.feed = [];           // propositions visibles par tous
    this.strokes = [];        // [{s, c, w, p:[x,y,…]}]
    this.revealed = new Set(); // positions de lettres dévoilées
    this.hintTimers = [];
    this.podiumMs = DSN.podiumMs;
  }

  start() {
    this.schedule(DSN.introMs, () => this.nextTurn());
  }

  stop() {
    super.stop();
    this.hintTimers.forEach(clearTimeout);
  }

  nextTurn() {
    this.hintTimers.forEach(clearTimeout);
    this.hintTimers = [];
    // On saute les dessinateurs partis
    do { this.turn++; } while (this.turn < this.order.length && !this.room.players.get(this.order[this.turn])?.connected);
    if (this.turn >= this.order.length) return this.podium(DSN.podiumMs);
    this.drawer = this.order[this.turn];
    const start = (this.turn * 3) % Math.max(3, this.pool.length);
    this.choices = this.pool.slice(start, start + 3);
    if (this.choices.length < 3) this.choices = shuffle([...this.pool]).slice(0, 3);
    this.word = null;
    this.found.clear();
    this.feed = [];
    this.strokes = [];
    this.revealed.clear();
    this.gains.clear();
    this.phase = 'choose';
    this.hooks.emit({ t: 'draw', op: 'clear', turn: this.turn });
    this.schedule(DSN.chooseMs, () => this.choose(0));
    this.changed();
  }

  choose(i) {
    if (this.phase !== 'choose') return;
    this.word = (this.choices[i] || this.choices[0]).word;
    this.phase = 'draw';
    this.startedAt = Date.now();
    this.schedule(DSN.drawMs, () => this.reveal());
    // Indices : une lettre à 50 %, une autre à 75 % (jamais toutes)
    const letters = [...this.word].map((ch, i) => (/[\p{L}\p{N}]/u.test(ch) ? i : -1)).filter((i) => i >= 0);
    const hints = letters.length >= 4 ? 2 : letters.length >= 3 ? 1 : 0;
    shuffle(letters).slice(0, hints).forEach((pos, k) => {
      this.hintTimers.push(setTimeout(() => {
        if (this.over || this.phase !== 'draw') return;
        this.revealed.add(pos);
        this.changed();
      }, DSN.drawMs * (k === 0 ? 0.5 : 0.75)));
    });
    this.changed();
  }

  guessers() {
    return this.active().filter((p) => p.pid !== this.drawer);
  }

  reveal() {
    if (this.phase !== 'draw') return;
    this.phase = 'reveal';
    this.hintTimers.forEach(clearTimeout);
    this.schedule(DSN.revealMs, () => this.nextTurn());
    this.changed();
  }

  // Le mot masqué : _ pour les lettres, le reste (espaces, tirets…) visible
  mask() {
    if (!this.word) return null;
    return [...this.word].map((ch, i) => (!/[\p{L}\p{N}]/u.test(ch) || this.revealed.has(i) ? ch : '_')).join('');
  }

  pushFeed(entry) {
    this.feed.push(entry);
    if (this.feed.length > DSN.feedSize) this.feed.shift();
  }

  guess(p, raw) {
    const text = cleanText(raw, 30);
    if (!text) return;
    const g = fold(text);
    const w = fold(this.word);
    if (g === w) {
      const rank = this.found.size;
      this.found.set(p.pid, rank);
      const left = Math.max(0, 1 - (Date.now() - this.startedAt) / DSN.drawMs);
      this.addPoints(p.pid, DSN.findBase + Math.round((DSN.findSpeed * left) / 10) * 10 + (rank === 0 ? DSN.firstBonus : 0));
      this.addPoints(this.drawer, DSN.drawerPerFind);
      this.pushFeed({ pid: p.pid, found: true });
      this.hooks.sendTo(p.pid, { t: 'dsn_found', word: this.word });
      if (this.guessers().every((x) => this.found.has(x.pid))) this.schedule(900, () => this.reveal());
      this.changed();
      return;
    }
    const d = levenshtein(g, w);
    if (w.length >= 4 && d <= (w.length >= 8 ? 2 : 1)) {
      // Presque ! Seul celui qui l'a tapé le voit (sinon ça donne la réponse)
      this.hooks.sendTo(p.pid, { t: 'dsn_close', text });
      return;
    }
    this.pushFeed({ pid: p.pid, text });
    this.changed();
  }

  // ---- traits ----
  stroke(m) {
    if (!Number.isInteger(m.s) || !Array.isArray(m.p) || m.p.length < 2 || m.p.length % 2) return;
    const pts = m.p.map((v) => Math.max(0, Math.min(1000, Math.round(Number(v) || 0))));
    let st = this.strokes.find((x) => x.s === m.s);
    if (!st) {
      if (this.strokes.length >= DSN.maxStrokes) return;
      const c = Number.isInteger(m.c) ? ((m.c % DSN.colors) + DSN.colors) % DSN.colors : 0;
      const w = Math.max(1, Math.min(DSN.maxWidth, Math.round(Number(m.w) || 8)));
      st = { s: m.s, c, w, p: [] };
      this.strokes.push(st);
    }
    if (st.p.length + pts.length > DSN.maxPointsPerStroke) return;
    st.p.push(...pts);
    this.hooks.emit({ t: 'draw', op: 'pts', turn: this.turn, s: st.s, c: st.c, w: st.w, p: pts }, this.drawer);
  }

  sync(target) {
    this.hooks.sendTo(target, { t: 'draw', op: 'full', turn: this.turn, strokes: this.strokes });
  }

  onMessage(p, m) {
    if (m.t === 'drw_sync') return this.sync(p.pid);
    const isDrawer = p.pid === this.drawer;
    if (isDrawer && this.phase === 'choose' && m.t === 'dsn_choose') {
      if (Number.isInteger(m.i) && m.i >= 0 && m.i < this.choices.length) this.choose(m.i);
      return;
    }
    if (isDrawer && this.phase === 'draw') {
      if (m.t === 'drw_stroke') return this.stroke(m);
      if (m.t === 'drw_undo') {
        const st = this.strokes.pop();
        if (st) this.hooks.emit({ t: 'draw', op: 'undo', turn: this.turn, s: st.s }, this.drawer);
        return;
      }
      if (m.t === 'drw_clear') {
        this.strokes = [];
        this.hooks.emit({ t: 'draw', op: 'clear', turn: this.turn }, this.drawer);
        return;
      }
    }
    if (m.t === 'dsn_guess' && this.phase === 'draw' && !isDrawer && !this.found.has(p.pid)) {
      this.onPlayerJoin(p);
      return this.guess(p, m.text);
    }
    this.hostCommand(p, m, () => {
      if (this.phase === 'intro' || this.phase === 'reveal') this.nextTurn();
      else if (this.phase === 'choose') this.choose(0);
      else if (this.phase === 'draw') this.reveal();
    });
  }

  onTvMessage(m) {
    if (m.t === 'drw_sync') this.sync('tv');
  }

  onPlayerGone(p) {
    if (this.phase === 'choose' && p.pid === this.drawer) this.nextTurn();
    else if (this.phase === 'draw' && p.pid === this.drawer) this.reveal();
    else if (this.phase === 'draw' && this.guessers().length && this.guessers().every((x) => this.found.has(x.pid))) {
      this.schedule(900, () => this.reveal());
    }
  }

  publicState() {
    const s = {
      ...this.base('dessin'),
      turn: this.turn,
      turns: this.order.length,
      drawer: this.drawer,
    };
    if (this.phase === 'draw' || this.phase === 'reveal') {
      s.mask = this.phase === 'reveal' ? this.word : this.mask();
      s.found = [...this.found.keys()];
      s.feed = this.feed;
      s.strokes = this.strokes.length;
    }
    if (this.phase === 'reveal') s.word = this.word;
    return s;
  }

  playerState(pid) {
    const r = this.ranking().find((x) => x.pid === pid);
    const drawer = pid === this.drawer;
    return {
      drawer,
      choices: drawer && this.phase === 'choose' ? this.choices.map((c) => c.word) : null,
      word: (drawer || this.found.has(pid)) && this.word ? this.word : null,
      found: this.found.has(pid),
      gain: this.phase === 'reveal' ? (this.gains.get(pid) || 0) : null,
      score: r?.score ?? 0,
      rank: r?.rank ?? null,
      players: this.ranking().length,
    };
  }
}
