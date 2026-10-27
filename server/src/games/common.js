// Outils partagés par les jeux.
import crypto from 'node:crypto';

export function shuffle(a) {
  for (let i = a.length - 1; i > 0; i--) {
    const j = crypto.randomInt(i + 1);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

// PB_FAST=1 (tests) : tous les délais ÷10
export function fastTimings(obj) {
  if (process.env.PB_FAST) for (const k of Object.keys(obj)) if (k.endsWith('Ms')) obj[k] = Math.round(obj[k] / 10);
  return obj;
}

// Texte tapé par un joueur : sans caractères invisibles, espaces normalisés, longueur max
export function cleanText(raw, max) {
  if (typeof raw !== 'string') return '';
  const s = raw.normalize('NFC').replace(/[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]/gu, '').replace(/\s+/g, ' ').trim();
  return [...s].slice(0, max).join('');
}

// Pour comparer des mots : minuscules, sans accents ni ponctuation
export function fold(s) {
  return String(s).normalize('NFKD').replace(/\p{M}/gu, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
}

// Distance d'édition (pour « chaud ! » au dessin)
export function levenshtein(a, b) {
  if (a === b) return 0;
  const m = a.length, n = b.length;
  if (!m) return n;
  if (!n) return m;
  let prev = Array.from({ length: n + 1 }, (_, j) => j);
  for (let i = 1; i <= m; i++) {
    const cur = [i];
    for (let j = 1; j <= n; j++) {
      cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    }
    prev = cur;
  }
  return prev[n];
}

// Classement à partir d'une Map pid -> score (ex aequo = même rang)
export function rankScores(scores, room) {
  const list = [...scores.entries()]
    .filter(([pid]) => room.players.has(pid))
    .map(([pid, score]) => ({ pid, score }))
    .sort((a, b) => b.score - a.score);
  let rank = 0;
  let prev = null;
  list.forEach((r, i) => {
    if (r.score !== prev) { rank = i + 1; prev = r.score; }
    r.rank = rank;
  });
  return list;
}

export function resultsOf(scores, room) {
  return rankScores(scores, room).map((r) => ({ pid: r.pid, name: room.players.get(r.pid)?.name ?? '?', score: r.score, rank: r.rank }));
}

// Base commune : minuteur, phases, scores, classement, podium
export class BaseGame {
  constructor(room, hooks) {
    this.room = room;
    this.hooks = hooks;
    this.timer = null;
    this.deadline = Date.now();
    this.duration = 0;
    this.over = false;
    this.phase = 'intro';
    this.scores = new Map();
    this.gains = new Map();
    for (const p of room.players.values()) this.scores.set(p.pid, 0);
  }

  schedule(ms, fn) {
    clearTimeout(this.timer);
    this.duration = ms;
    this.deadline = Date.now() + ms;
    this.timer = setTimeout(() => { if (!this.over) fn(); }, ms);
  }

  stop() {
    clearTimeout(this.timer);
    this.over = true;
  }

  changed() { this.hooks.changed(); }

  active() { return [...this.room.players.values()].filter((p) => p.connected); }

  addPoints(pid, pts) {
    this.gains.set(pid, (this.gains.get(pid) || 0) + pts);
    this.scores.set(pid, (this.scores.get(pid) || 0) + pts);
  }

  onPlayerJoin(p) { if (!this.scores.has(p.pid)) this.scores.set(p.pid, 0); }

  ranking() {
    return rankScores(this.scores, this.room).map((r) => ({ ...r, gain: this.gains.get(r.pid) || 0 }));
  }

  results() { return resultsOf(this.scores, this.room); }

  // Podium final, retour au salon après podiumMs
  podium(ms) {
    if (this.phase === 'podium') return;
    this.phase = 'podium';
    this.schedule(ms, () => this.hooks.finished(this.results()));
    this.changed();
  }

  // Éléments communs de l'état public
  base(id) {
    return {
      id,
      phase: this.phase,
      endsIn: Math.max(0, this.deadline - Date.now()),
      duration: this.duration,
      ranking: this.ranking(),
    };
  }

  // Commandes communes de l'hôte
  hostCommand(p, m, next) {
    if (p.pid !== this.room.hostPid) return false;
    if (m.t === 'game_end') { this.podium(this.podiumMs); return true; }
    if (m.t === 'game_skip') {
      if (this.phase === 'podium') this.hooks.finished(this.results());
      else next();
      return true;
    }
    return false;
  }
}

// Charge du contenu en base pour une partie, sans répéter ce qui a servi ce soir
export async function loadContent(db, room, table, cols, n, emptyMsg) {
  if (!db.enabled()) throw new Error('Le contenu des jeux est dans la base, et elle n’est pas configurée');
  room.used[table] ??= new Set();
  let rows = await db.randomContent(table, cols, n, [...room.used[table]]);
  if (rows === null) throw new Error('Base de données injoignable, réessaie');
  if (rows.length < n) {
    // Tout a déjà servi : on repart de zéro pour ce jeu
    room.used[table].clear();
    rows = await db.randomContent(table, cols, n, []);
    if (rows === null) throw new Error('Base de données injoignable, réessaie');
  }
  if (rows.length === 0) throw new Error(emptyMsg);
  for (const r of rows) room.used[table].add(r.id);
  return rows;
}
