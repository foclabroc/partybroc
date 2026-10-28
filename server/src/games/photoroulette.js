// Photo roulette : chacun choisit quelques photos de son téléphone, puis la TV les montre
// une par une et tout le monde devine à qui elle appartient (le propriétaire se tait).
// Les photos restent dans la mémoire du serveur le temps de la partie (jamais en base),
// servies par /r/CODE/id (id aléatoire). Le propriétaire n'est JAMAIS envoyé avant la révélation.
import crypto from 'node:crypto';
import { fastTimings, shuffle } from './common.js';
import { RoundGame } from './round.js';

export const PHR = fastTimings({
  perPlayer: [3, 4, 5],
  defaultPerPlayer: 4,
  maxRounds: 40,
  introMs: 6000,
  pickMs: 150000,
  askMs: 15000,
  revealMs: 6000,
  podiumMs: 25000,
  findPoints: 500,      // + rapidité
  speedPoints: 300,
  fooledPoints: 50,     // pour le propriétaire, par joueur qui s'est trompé
  maxBytes: 220 * 1024, // une photo (déjà réduite par le téléphone)
});

// JPEG, PNG ou WebP en base64 (signature vérifiée)
export function decodeImage(b64, max) {
  if (typeof b64 !== 'string' || !b64 || b64.length > max * 1.4) return null;
  const buf = Buffer.from(b64.replace(/^data:image\/\w+;base64,/, ''), 'base64');
  if (buf.length < 16 || buf.length > max) return null;
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return { buf, type: 'image/jpeg' };
  if (buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return { buf, type: 'image/png' };
  if (buf.subarray(0, 4).toString() === 'RIFF' && buf.subarray(8, 12).toString() === 'WEBP') return { buf, type: 'image/webp' };
  return null;
}

export class PhotoRouletteGame extends RoundGame {
  static id = 'photoroulette';

  static async create(room, opts, hooks) {
    return new PhotoRouletteGame(room, hooks, opts);
  }

  constructor(room, hooks, opts) {
    super(room, hooks, { id: 'photoroulette', count: 0, answerType: 'phr_guess', ...PHR });
    this.per = PHR.perPlayer.includes(opts?.per) ? opts.per : PHR.defaultPerPlayer;
    this.photos = new Map();   // id -> { id, owner, buf, type }
    this.finished = new Set(); // joueurs qui ont dit « j'ai fini »
    this.entries = [];
  }

  start() {
    this.schedule(PHR.introMs, () => this.pick());
  }

  stop() {
    super.stop();
    this.photos.clear(); // les photos disparaissent avec la partie
  }

  pick() {
    this.phase = 'pick';
    this.schedule(PHR.pickMs, () => this.build());
    this.changed();
  }

  mine(pid) { return [...this.photos.values()].filter((x) => x.owner === pid); }
  isDone(pid) { return this.finished.has(pid) || this.mine(pid).length >= this.per; }
  allDone() { return this.active().every((p) => this.isDone(p.pid)); }

  // Les photos deviennent les manches : mélangées, sans deux fois le même propriétaire d'affilée si possible
  build() {
    if (this.phase !== 'pick') return;
    const pool = shuffle([...this.photos.values()].filter((x) => this.room.players.has(x.owner)));
    const ordered = [];
    while (pool.length) {
      const i = pool.findIndex((e) => e.owner !== ordered.at(-1)?.owner);
      ordered.push(...pool.splice(i < 0 ? 0 : i, 1));
    }
    this.entries = ordered.slice(0, PHR.maxRounds);
    this.count = this.entries.length;
    if (this.count === 0) return this.podium(PHR.podiumMs);
    this.next();
  }

  // Photo servie par HTTP : seulement celle de la manche en cours (ou déjà passée)
  photo(id) {
    const ph = this.photos.get(id);
    if (!ph) return null;
    const at = this.entries.indexOf(ph);
    return at >= 0 && at <= this.index && ['ask', 'reveal', 'podium'].includes(this.phase) ? ph : null;
  }

  makeRound(i) { return this.entries[i]; }

  answerers() { return this.active().filter((p) => p.pid !== this.round?.owner); }

  accept(p, m) {
    return typeof m.pid === 'string' && m.pid !== p.pid && this.room.players.has(m.pid) ? m.pid : undefined;
  }

  scoreRound() {
    const owner = this.round.owner;
    let fooled = 0;
    for (const [pid, a] of this.answers) {
      if (a.v === owner) this.addPoints(pid, PHR.findPoints + Math.round((PHR.speedPoints * this.speed(a.at)) / 10) * 10);
      else fooled++;
    }
    if (fooled) this.addPoints(owner, fooled * PHR.fooledPoints);
  }

  checkPick() {
    if (this.phase === 'pick' && this.active().length && this.allDone()) this.schedule(800, () => this.build());
  }

  onOther(p, m) {
    if (!['phr_photo', 'phr_clear', 'phr_done'].includes(m.t)) return false;
    if (this.phase !== 'pick') return true;
    if (m.t === 'phr_photo') {
      if (this.isDone(p.pid)) return true;
      const img = decodeImage(m.data, PHR.maxBytes);
      if (!img) { this.hooks.sendTo(p.pid, { t: 'error', code: 'bad_photo', msg: 'Photo refusée (trop lourde ou format inconnu)' }); return true; }
      const id = crypto.randomBytes(8).toString('hex');
      this.photos.set(id, { id, owner: p.pid, ...img });
    } else if (m.t === 'phr_clear') {
      for (const ph of this.mine(p.pid)) this.photos.delete(ph.id);
      this.finished.delete(p.pid);
    } else if (m.t === 'phr_done') {
      if (this.mine(p.pid).length) this.finished.add(p.pid);
    }
    this.checkPick();
    this.changed();
    return true;
  }

  onPlayerGone() {
    if (this.phase === 'pick') this.checkPick();
    else super.onPlayerGone();
  }

  // L'hôte : depuis l'intro on passe au choix des photos, et il peut le couper
  onMessage(p, m) {
    if (m.t === 'game_skip' && p.pid === this.room.hostPid) {
      if (this.phase === 'intro') return this.pick();
      if (this.phase === 'pick') return this.build();
    }
    return super.onMessage(p, m);
  }

  publicRound(reveal) {
    const s = { photo: `/r/${this.room.code}/${this.round.id}` };
    if (reveal) {
      s.owner = this.round.owner;
      s.picks = Object.fromEntries([...this.answers].map(([pid, a]) => [pid, a.v]));
    }
    return s;
  }

  publicState() {
    const s = super.publicState();
    s.per = this.per;
    if (this.phase === 'pick') {
      s.done = this.active().filter((p) => this.isDone(p.pid)).map((p) => p.pid);
      s.counts = Object.fromEntries(this.active().map((p) => [p.pid, this.mine(p.pid).length]));
    }
    return s;
  }

  playerRound(pid) {
    return {
      mine: this.round?.owner === pid && ['ask', 'reveal'].includes(this.phase),
      sent: this.mine(pid).length,
      done: this.isDone(pid),
    };
  }
}
