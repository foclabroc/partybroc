// Quiz culture G : une question, 4 réponses, le plus rapide marque le plus.
// La bonne réponse n'est JAMAIS envoyée aux clients avant la révélation.
import crypto from 'node:crypto';
import { db } from '../db.js';

export const QUIZ = {
  counts: [5, 10, 15, 20],
  defaultCount: 10,
  introMs: 4000,
  questionMs: 20000,
  revealMs: 6000,
  scoresMs: 5000,
  podiumMs: 25000,
  basePoints: 500,      // bonne réponse
  speedPoints: 500,     // + jusqu'à 500 selon la rapidité
  streakBonus: 100,     // + 100 par bonne réponse d'affilée (à partir de la 2e)
  streakMax: 300,
};

// Tests automatiques : PB_FAST=1 accélère tous les délais (×10)
if (process.env.PB_FAST) for (const k of Object.keys(QUIZ)) if (k.endsWith('Ms')) QUIZ[k] = Math.round(QUIZ[k] / 10);

function shuffle(a) {
  for (let i = a.length - 1; i > 0; i--) {
    const j = crypto.randomInt(i + 1);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

export class QuizGame {
  static id = 'quiz';

  // Charge les questions avant de lancer (évite celles déjà posées ce soir)
  static async create(room, opts, hooks) {
    const count = QUIZ.counts.includes(opts?.count) ? opts.count : QUIZ.defaultCount;
    if (!db.enabled()) throw new Error('Les questions sont dans la base, et elle n’est pas configurée');
    const rows = await db.quizQuestions(count, [...room.usedQuiz]);
    if (rows === null) throw new Error('Base de données injoignable, réessaie');
    if (rows.length === 0) throw new Error('Plus de questions disponibles ce soir !');
    for (const r of rows) room.usedQuiz.add(r.id);
    return new QuizGame(room, rows, hooks);
  }

  constructor(room, rows, hooks) {
    this.room = room;
    this.hooks = hooks; // { changed(), finished(results) }
    this.questions = rows.map((r) => {
      const answers = shuffle([r.good, ...r.bad]);
      return { category: r.category, difficulty: r.difficulty, text: r.question, answers, correct: answers.indexOf(r.good) };
    });
    this.index = -1;
    this.phase = 'intro';
    this.deadline = Date.now() + QUIZ.introMs;
    this.picks = new Map();   // pid -> { choice, at } pour la question en cours
    this.gains = new Map();   // pid -> points gagnés à la question en cours
    this.scores = new Map();  // pid -> score de la partie
    this.prevRank = new Map();
    this.streaks = new Map();
    this.timer = null;
    this.over = false;
  }

  start() {
    for (const p of this.room.players.values()) this.scores.set(p.pid, 0);
    this.schedule(QUIZ.introMs, () => this.nextQuestion());
  }

  stop() {
    clearTimeout(this.timer);
    this.timer = null;
    this.over = true;
  }

  schedule(ms, fn) {
    clearTimeout(this.timer);
    this.deadline = Date.now() + ms;
    this.timer = setTimeout(() => { if (!this.over) fn(); }, ms);
  }

  get q() { return this.questions[this.index]; }

  // Joueurs qui doivent répondre : connectés
  active() {
    return [...this.room.players.values()].filter((p) => p.connected);
  }

  nextQuestion() {
    this.index++;
    if (this.index >= this.questions.length) return this.podium();
    this.picks.clear();
    this.gains.clear();
    this.phase = 'question';
    this.questionStart = Date.now();
    this.schedule(QUIZ.questionMs, () => this.reveal());
    this.hooks.changed();
  }

  reveal() {
    if (this.phase !== 'question') return;
    this.phase = 'reveal';
    this.prevRank = new Map(this.ranking().map((r) => [r.pid, r.rank]));
    for (const p of this.room.players.values()) {
      const pick = this.picks.get(p.pid);
      let pts = 0;
      if (pick && pick.choice === this.q.correct) {
        const left = Math.max(0, 1 - (pick.at - this.questionStart) / QUIZ.questionMs);
        const streak = (this.streaks.get(p.pid) || 0) + 1;
        this.streaks.set(p.pid, streak);
        pts = QUIZ.basePoints + Math.round((QUIZ.speedPoints * left) / 10) * 10
          + Math.min(QUIZ.streakMax, QUIZ.streakBonus * (streak - 1));
      } else {
        this.streaks.set(p.pid, 0);
      }
      this.gains.set(p.pid, pts);
      this.scores.set(p.pid, (this.scores.get(p.pid) || 0) + pts);
    }
    const last = this.index === this.questions.length - 1;
    this.schedule(QUIZ.revealMs, () => (last ? this.podium() : this.showScores()));
    this.hooks.changed();
  }

  showScores() {
    this.phase = 'scores';
    this.schedule(QUIZ.scoresMs, () => this.nextQuestion());
    this.hooks.changed();
  }

  podium() {
    if (this.phase === 'podium') return;
    this.phase = 'podium';
    this.schedule(QUIZ.podiumMs, () => this.hooks.finished(this.results()));
    this.hooks.changed();
  }

  // ---- messages des téléphones ----
  onMessage(p, m) {
    if (m.t === 'quiz_answer') {
      if (this.phase !== 'question' || m.q !== this.index) return;
      if (this.picks.has(p.pid)) return; // une seule réponse, pas de changement
      const c = m.choice;
      if (!Number.isInteger(c) || c < 0 || c > 3) return;
      this.picks.set(p.pid, { choice: c, at: Date.now() });
      if (!this.scores.has(p.pid)) this.scores.set(p.pid, 0);
      // Tout le monde a répondu : on révèle tout de suite
      if (this.active().every((x) => this.picks.has(x.pid))) {
        this.schedule(600, () => this.reveal());
      }
      this.hooks.changed();
      return;
    }
    if (p.pid !== this.room.hostPid) return;
    if (m.t === 'game_skip') {
      // L'hôte passe à la suite (utile si quelqu'un traîne)
      if (this.phase === 'intro' || this.phase === 'scores') this.nextQuestion();
      else if (this.phase === 'question') this.reveal();
      else if (this.phase === 'reveal') (this.index === this.questions.length - 1 ? this.podium() : this.showScores());
      else if (this.phase === 'podium') this.hooks.finished(this.results());
    } else if (m.t === 'game_end') {
      this.podium();
    }
  }

  onPlayerJoin(p) {
    if (!this.scores.has(p.pid)) this.scores.set(p.pid, 0);
  }

  onPlayerGone() {
    // Un joueur part pendant la question : si tous les autres ont répondu, on révèle
    if (this.phase === 'question' && this.active().length > 0
        && this.active().every((x) => this.picks.has(x.pid))) {
      this.schedule(600, () => this.reveal());
    }
  }

  // ---- classement ----
  ranking() {
    const list = [...this.scores.entries()]
      .filter(([pid]) => this.room.players.has(pid))
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

  results() {
    return this.ranking().map((r) => ({ pid: r.pid, name: this.room.players.get(r.pid)?.name ?? '?', score: r.score, rank: r.rank }));
  }

  // ---- ce que voient la TV et tout le monde ----
  publicState() {
    const s = {
      id: 'quiz',
      phase: this.phase,
      index: this.index,
      count: this.questions.length,
      endsIn: Math.max(0, this.deadline - Date.now()),
      ranking: this.ranking().map((r) => ({
        ...r,
        gain: this.gains.get(r.pid) || 0,
        prevRank: this.prevRank.get(r.pid) ?? r.rank,
        streak: this.streaks.get(r.pid) || 0,
      })),
    };
    if (this.phase === 'intro') {
      s.duration = QUIZ.introMs;
    }
    if (this.q && (this.phase === 'question' || this.phase === 'reveal')) {
      s.category = this.q.category;
      s.difficulty = this.q.difficulty;
      s.question = this.q.text;
      s.answers = this.q.answers;
      s.duration = QUIZ.questionMs;
      s.answered = [...this.picks.keys()];
    }
    if (this.phase === 'reveal') {
      s.correct = this.q.correct;
      s.picks = Object.fromEntries([...this.picks].map(([pid, v]) => [pid, v.choice]));
      s.duration = QUIZ.revealMs;
    }
    if (this.phase === 'scores') s.duration = QUIZ.scoresMs;
    if (this.phase === 'podium') s.duration = QUIZ.podiumMs;
    return s;
  }

  // ---- ce que voit chaque téléphone en plus ----
  playerState(pid) {
    const r = this.ranking().find((x) => x.pid === pid);
    const pick = this.picks.get(pid);
    return {
      choice: pick ? pick.choice : null,
      gain: this.phase === 'reveal' || this.phase === 'scores' ? (this.gains.get(pid) || 0) : null,
      score: r?.score ?? 0,
      rank: r?.rank ?? null,
      streak: this.streaks.get(pid) || 0,
      players: this.ranking().length,
    };
  }
}
