// Course au tap : de vraies courses à pied sur la TV. On avance en tapant
// GAUCHE puis DROITE en alternance sur son téléphone (deux fois le même pied ne compte pas).
//   sprint : ligne droite
//   haies  : des haies à sauter (bouton SAUTE) ; ratée = on trébuche 1 s
//   turbo  : haies + bonus ⚡ (2 s où chaque pas compte double)
// Le téléphone compte ses pas et gère sauts / turbo (les haies et bonus sont aux mêmes
// endroits pour tout le monde) ; le serveur plafonne la vitesse et le temps d'arrivée.
import crypto from 'node:crypto';
import { BaseGame, fastTimings } from './common.js';

export const CRS = fastTimings({
  races: [3, 5],
  defaultRaces: 3,
  introMs: 6000,
  readyMs: 4000,
  resultMs: 7000,
  podiumMs: 25000,
  // longueur (en pas) et temps maximum de chaque type de course
  kinds: {
    sprint: { length: 60, capMs: 20000 },
    haies: { length: 80, capMs: 30000 },
    turbo: { length: 100, capMs: 35000 },
  },
  points: [500, 400, 300, 200], // 1er, 2e, 3e, les autres arrivés
  unfinished: 100,              // pas arrivé mais parti
  maxStepsPerSec: 24,           // 2 pouces très rapides + turbo
});

// Tests (PB_FAST) : temps maximum des courses ÷4 (il faut pouvoir arriver à la vitesse max)
if (process.env.PB_FAST) for (const k of Object.values(CRS.kinds)) k.capMs = Math.round(k.capMs / 4);

const ORDER = ['sprint', 'haies', 'turbo', 'haies', 'turbo'];

// Haies régulières avec un peu de hasard, jamais au départ ni sur la ligne
function hurdles(length, n) {
  const gap = length / (n + 1);
  return Array.from({ length: n }, (_, i) => Math.round(gap * (i + 1) + crypto.randomInt(5) - 2));
}

export class CourseGame extends BaseGame {
  static id = 'course';

  static async create(room, opts, hooks) {
    const n = CRS.races.includes(opts?.races) ? opts.races : CRS.defaultRaces;
    return new CourseGame(room, ORDER.slice(0, n), hooks);
  }

  constructor(room, kinds, hooks) {
    super(room, hooks);
    this.kinds = kinds;
    this.index = -1;
    this.race = null;
    this.podiumMs = CRS.podiumMs;
    this.throttle = null;
  }

  start() {
    this.schedule(CRS.introMs, () => this.nextRace());
  }

  stop() {
    super.stop();
    clearTimeout(this.throttle);
  }

  // Les positions arrivent souvent : on regroupe les rediffusions (5 par seconde)
  changedSoon() {
    if (this.throttle) return;
    this.throttle = setTimeout(() => { this.throttle = null; if (!this.over) this.changed(); }, 200);
  }

  nextRace() {
    this.index++;
    if (this.index >= this.kinds.length) return this.podium(CRS.podiumMs);
    const kind = this.kinds[this.index];
    const { length, capMs } = CRS.kinds[kind];
    const hs = kind === 'sprint' ? [] : hurdles(length, kind === 'haies' ? 4 : 5);
    // Turbos entre deux haies (jamais sur une haie)
    const turbos = kind === 'turbo' ? [hs[0] + Math.round((hs[1] - hs[0]) / 2), hs[2] + Math.round((hs[3] - hs[2]) / 2)] : [];
    this.gains.clear();
    this.race = { kind, length, capMs, hurdles: hs, turbos, pos: new Map(), stumbles: new Map(), finish: new Map(), startedAt: 0 };
    this.phase = 'ready';
    this.schedule(CRS.readyMs, () => this.go());
    this.changed();
  }

  go() {
    this.phase = 'go';
    this.race.startedAt = Date.now();
    this.schedule(this.race.capMs, () => this.result());
    this.changed();
  }

  allDone() {
    const act = this.active();
    return act.length > 0 && act.every((p) => this.race.finish.has(p.pid));
  }

  onMessage(p, m) {
    const r = this.race;
    if (m.t === 'crs' && r && m.k === this.index && this.phase === 'go') {
      this.onPlayerJoin(p);
      if (r.finish.has(p.pid)) return;
      const seen = Date.now() - r.startedAt;
      const cap = Math.ceil(((seen + 500) / 1000) * CRS.maxStepsPerSec);
      const n = Math.max(0, Math.min(Math.floor(Number(m.n) || 0), cap, r.length));
      r.pos.set(p.pid, Math.max(r.pos.get(p.pid) || 0, n));
      const st = Math.max(0, Math.min(Math.floor(Number(m.s) || 0), r.hurdles.length));
      r.stumbles.set(p.pid, Math.max(r.stumbles.get(p.pid) || 0, st));
      if (r.pos.get(p.pid) >= r.length) {
        // Temps du téléphone, borné : jamais plus vite que la vitesse max, jamais plus tard que vu ici
        const best = Math.ceil((r.length / CRS.maxStepsPerSec) * 1000);
        const v = Number(m.ms);
        const ms = Math.max(best, Math.min(Number.isFinite(v) ? Math.round(v) : seen, seen + 300));
        r.finish.set(p.pid, ms);
        if (this.allDone()) this.schedule(1200, () => this.result());
        return this.changed();
      }
      return this.changedSoon();
    }
    this.hostCommand(p, m, () => {
      if (this.phase === 'intro' || this.phase === 'result') this.nextRace();
      else if (this.phase === 'ready') this.go();
      else if (this.phase === 'go') this.result();
    });
  }

  onPlayerGone() {
    if (this.phase === 'go' && this.allDone()) this.schedule(1200, () => this.result());
  }

  // Classement de la course : arrivés par temps, puis les autres par distance
  result() {
    if (this.phase === 'result' || !this.race) return;
    const r = this.race;
    const arrived = [...r.finish].sort((a, b) => a[1] - b[1]);
    const others = [...r.pos].filter(([pid, n]) => !r.finish.has(pid) && n > 0).sort((a, b) => b[1] - a[1]);
    r.order = [];
    let place = 0;
    let prev = null;
    arrived.forEach(([pid, ms], i) => {
      if (ms !== prev) { place = i; prev = ms; }
      const pts = CRS.points[Math.min(place, CRS.points.length - 1)];
      this.addPoints(pid, pts);
      r.order.push({ pid, place: place + 1, ms, pts });
    });
    others.forEach(([pid, n], i) => {
      this.addPoints(pid, CRS.unfinished);
      r.order.push({ pid, place: arrived.length + i + 1, n, pts: CRS.unfinished });
    });
    clearTimeout(this.throttle);
    this.throttle = null;
    this.phase = 'result';
    const last = this.index === this.kinds.length - 1;
    this.schedule(CRS.resultMs, () => (last ? this.podium(CRS.podiumMs) : this.nextRace()));
    this.changed();
  }

  publicState() {
    const s = { ...this.base('course'), index: this.index, count: this.kinds.length };
    const r = this.race;
    if (!r || this.phase === 'intro' || this.phase === 'podium') return s;
    Object.assign(s, {
      kind: r.kind,
      length: r.length,
      hurdles: r.hurdles,
      turbos: r.turbos,
      pos: Object.fromEntries(r.pos),
      stumbles: Object.fromEntries(r.stumbles),
      finish: Object.fromEntries(r.finish),
    });
    if (this.phase === 'result') s.order = r.order;
    return s;
  }

  playerState(pid) {
    const r = this.race;
    const rk = this.ranking().find((x) => x.pid === pid);
    const o = this.phase === 'result' ? r?.order.find((x) => x.pid === pid) : null;
    return {
      pos: r?.pos.get(pid) ?? 0,
      finish: r?.finish.get(pid) ?? null,
      place: o?.place ?? null,
      gain: this.phase === 'result' ? (this.gains.get(pid) || 0) : null,
      score: rk?.score ?? 0,
      rank: rk?.rank ?? null,
      players: this.ranking().length,
    };
  }
}
