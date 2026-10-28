// Petit bac : une lettre, 5 catégories, chacun écrit un mot par catégorie.
// Le premier qui a tout rempli peut crier « Stop ! » : les autres ont encore 10 secondes.
// Puis tout le monde voit les réponses et peut refuser celles des autres (à la majorité).
// Points par catégorie : seul à avoir une réponse valable 150, réponse unique 100, même réponse qu'un autre 50.
import { BaseGame, cleanText, fastTimings, fold, shuffle } from './common.js';

export const PBAC = fastTimings({
  rounds: [3, 5, 8],
  defaultRounds: 3,
  introMs: 7000,
  writeMs: 90000,
  stopMs: 10000,
  checkMs: 35000,
  revealMs: 9000,
  podiumMs: 25000,
  categoriesPerGame: 5,
  alonePoints: 150,
  uniquePoints: 100,
  sharedPoints: 50,
  maxLen: 30,
});

export const PBAC_CATEGORIES = [
  'Prénom', 'Pays', 'Ville', 'Animal', 'Fruit ou légume', 'Métier', 'Objet de la maison', 'Marque',
  'Sport', 'Film ou série', 'Plat ou dessert', 'Partie du corps', 'Moyen de transport', 'Instrument de musique',
  'Vêtement', 'Personnage de dessin animé', 'Chanteur ou chanteuse', 'Fleur ou plante', 'Boisson', 'Jouet ou jeu',
];
const LETTERS = 'ABCDEFGHIJLMNOPRSTV'.split('');

export class PetitBacGame extends BaseGame {
  static id = 'petitbac';

  static async create(room, opts, hooks) {
    return new PetitBacGame(room, hooks, opts);
  }

  constructor(room, hooks, opts) {
    super(room, hooks);
    this.count = PBAC.rounds.includes(opts?.rounds) ? opts.rounds : PBAC.defaultRounds;
    this.categories = shuffle([...PBAC_CATEGORIES]).slice(0, PBAC.categoriesPerGame);
    this.letters = shuffle([...LETTERS]).slice(0, this.count);
    this.index = -1;
    this.podiumMs = PBAC.podiumMs;
    this.sheets = new Map();   // pid -> [5 réponses]
    this.done = new Set();     // a fini d'écrire
    this.vetoes = new Map();   // "pid:c" -> Set des joueurs qui refusent
    this.ok = new Set();       // a fini de vérifier
    this.stopBy = null;
    this.table = [];           // résultat de la manche
  }

  get letter() { return this.letters[this.index]; }

  start() { this.schedule(PBAC.introMs, () => this.next()); }

  next() {
    this.index++;
    if (this.index >= this.count) return this.podium(PBAC.podiumMs);
    this.sheets.clear();
    this.done.clear();
    this.vetoes.clear();
    this.ok.clear();
    this.gains.clear();
    this.stopBy = null;
    this.table = [];
    this.phase = 'write';
    this.schedule(PBAC.writeMs, () => this.check());
    this.changed();
  }

  // Une réponse est recevable si elle commence par la lettre (accents ignorés)
  valid(text) {
    const f = fold(text || '');
    return f.length >= 2 && f[0] === this.letter.toLowerCase();
  }

  check() {
    if (this.phase !== 'write') return;
    this.phase = 'check';
    this.schedule(PBAC.checkMs, () => this.reveal());
    this.changed();
  }

  refused(pid, c) {
    const others = this.active().filter((p) => p.pid !== pid && this.sheets.has(p.pid)).length;
    const n = this.vetoes.get(`${pid}:${c}`)?.size || 0;
    return others > 0 && n * 2 > others;
  }

  reveal() {
    if (this.phase !== 'check') return;
    this.phase = 'reveal';
    this.table = this.categories.map((cat, c) => {
      const rows = [...this.sheets].map(([pid, sheet]) => {
        const text = sheet[c] || '';
        const ok = this.valid(text) && !this.refused(pid, c);
        return { pid, text, ok, refused: this.valid(text) && this.refused(pid, c), pts: 0 };
      });
      const good = rows.filter((r) => r.ok);
      for (const r of good) {
        const same = good.filter((x) => fold(x.text) === fold(r.text)).length;
        r.pts = good.length === 1 ? PBAC.alonePoints : same > 1 ? PBAC.sharedPoints : PBAC.uniquePoints;
        this.addPoints(r.pid, r.pts);
      }
      return { cat, rows };
    });
    this.schedule(PBAC.revealMs, () => (this.index >= this.count - 1 ? this.podium(PBAC.podiumMs) : this.next()));
    this.changed();
  }

  onMessage(p, m) {
    if (m.t === 'bac_write') {
      if (this.phase !== 'write' || m.r !== this.index || !Array.isArray(m.answers)) return;
      const sheet = this.categories.map((_, c) => cleanText(m.answers[c], PBAC.maxLen));
      this.sheets.set(p.pid, sheet);
      this.onPlayerJoin(p);
      if (m.done) {
        this.done.add(p.pid);
        // Tout rempli et « Stop ! » : 10 secondes pour les autres
        if (!this.stopBy && sheet.every((t) => this.valid(t))) {
          this.stopBy = p.pid;
          if (this.deadline - Date.now() > PBAC.stopMs) this.schedule(PBAC.stopMs, () => this.check());
        }
        if (this.active().every((x) => this.done.has(x.pid))) this.schedule(600, () => this.check());
        this.changed();
      }
      return;
    }
    if (m.t === 'bac_veto') {
      if (this.phase !== 'check' || m.r !== this.index) return;
      const c = m.c;
      if (typeof m.pid !== 'string' || m.pid === p.pid || !this.sheets.has(m.pid) || !Number.isInteger(c) || c < 0 || c >= this.categories.length) return;
      const key = `${m.pid}:${c}`;
      if (!this.vetoes.has(key)) this.vetoes.set(key, new Set());
      if (m.on) this.vetoes.get(key).add(p.pid); else this.vetoes.get(key).delete(p.pid);
      this.changed();
      return;
    }
    if (m.t === 'bac_ok') {
      if (this.phase !== 'check' || m.r !== this.index) return;
      this.ok.add(p.pid);
      if (this.active().every((x) => this.ok.has(x.pid))) this.schedule(600, () => this.reveal());
      this.changed();
      return;
    }
    this.hostCommand(p, m, () => {
      if (this.phase === 'intro') this.next();
      else if (this.phase === 'write') this.check();
      else if (this.phase === 'check') this.reveal();
      else if (this.phase === 'reveal') (this.index >= this.count - 1 ? this.podium(PBAC.podiumMs) : this.next());
    });
  }

  onPlayerGone() {
    if (this.phase === 'write' && this.active().length && this.active().every((x) => this.done.has(x.pid))) this.schedule(600, () => this.check());
    if (this.phase === 'check' && this.active().length && this.active().every((x) => this.ok.has(x.pid))) this.schedule(600, () => this.reveal());
  }

  publicState() {
    const s = { ...this.base('petitbac'), index: this.index, count: this.count, categories: this.categories };
    if (this.index >= 0 && this.phase !== 'podium') s.letter = this.letter;
    if (this.phase === 'write') {
      s.done = [...this.done];
      s.stopBy = this.stopBy;
    }
    // Les réponses ne sont montrées qu'une fois l'écriture finie
    if (this.phase === 'check') {
      s.sheets = Object.fromEntries([...this.sheets].map(([pid, sh]) => [pid, sh.map((t) => ({ t, ok: this.valid(t) }))]));
      s.vetoes = Object.fromEntries([...this.vetoes].filter(([, v]) => v.size).map(([k, v]) => [k, v.size]));
      s.ok = [...this.ok];
    }
    if (this.phase === 'reveal') s.table = this.table;
    return s;
  }

  playerState(pid) {
    const r = this.ranking().find((x) => x.pid === pid);
    const mine = [];
    for (const [k, v] of this.vetoes) if (v.has(pid)) mine.push(k);
    return {
      sheet: this.sheets.get(pid) || null,
      done: this.done.has(pid),
      ok: this.ok.has(pid),
      myVetoes: mine,
      gain: this.phase === 'reveal' ? (this.gains.get(pid) || 0) : null,
      score: r?.score ?? 0,
      rank: r?.rank ?? null,
      players: this.ranking().length,
    };
  }
}
