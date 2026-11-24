// Blind test : un extrait de 30 s (Deezer) passe sur la TV, chacun trouve sur son téléphone
// l'artiste (4 choix à gauche) et le titre (4 choix à droite). Un seul essai par colonne.
// Bon artiste / bon titre : 250 + rapidité (jusqu'à 250) chacun, les deux : +100.
// Phases : intro → load (l'extrait se charge sur les écrans) → ask (on écoute et on répond)
//          → reveal (pochette, artiste, titre ; l'extrait continue) → … → podium.
// Les mauvaises réponses viennent de la même playlist (même époque, même style).
import { fastTimings, shuffle, BaseGame } from './common.js';
import { loadTracks, freshPreview, fold, cleanAlbum } from '../deezer.js';

export const BT = fastTimings({
  rounds: [10, 15, 20],
  defaultRounds: 10,
  listens: ['15 s', '20 s', '30 s'],
  defaultListen: '20 s',
  introMs: 8000,
  loadMs: 2500,     // l'extrait se charge sur la TV avant le départ
  waitMs: 6000,     // au plus, si Deezer met du temps à répondre
  revealMs: 8000,
  podiumMs: 25000,
  basePoints: 250,
  speedPoints: 250,
  bothBonus: 100,
});

// Playlists éditoriales de Deezer (France) ; Mélange = toutes
export const BT_PLAYLISTS = [
  { name: 'Années 70', sources: [{ playlist: 1470022445 }, { playlist: 821019291 }] },
  { name: 'Années 80', sources: [{ playlist: 867825522 }, { playlist: 791349661 }] },
  { name: 'Années 90', sources: [{ playlist: 878989033 }, { playlist: 1051470831 }] },
  { name: 'Années 2000', sources: [{ playlist: 11837091441 }, { playlist: 713806955 }] },
  { name: 'Années 2010', sources: [{ playlist: 715215865 }, { playlist: 1162725851 }] },
  { name: 'Années 2020', sources: [{ playlist: 13650084141 }, { playlist: 1139670951 }] },
  { name: 'Tubes du moment', sources: [{ playlist: 1109890291 }, { chart: true }] },
  { name: 'Chanson française', sources: [{ playlist: 700895155 }, { playlist: 1420459465 }] },
  // Disney : à gauche, le film plutôt que le chanteur (souvent un doubleur inconnu)
  { name: 'Disney', left: 'film', sources: [{ playlist: 613860315 }] },
  { name: 'Films et séries', sources: [{ playlist: 6238866284 }, { playlist: 6223140704 }, { playlist: 6478306844 }, { playlist: 754776991 }, { playlist: 6166580664 }] },
  { name: 'Génériques télé', sources: [{ playlist: 9976576142 }] },
  { name: 'Dessins animés', sources: [{ playlist: 15999794903 }, { playlist: 15141056763 }, { playlist: 15938341603 }, { playlist: 15979242483 }] },
  { name: 'Rock', sources: [{ playlist: 1306931615 }, { playlist: 8621268482 }, { playlist: 847814561 }] },
  // Rap tout public : « Le Rap pour les Kids » sans les étrangers, + classiques choisis (artists = seulement eux)
  { name: 'Rap français', sources: [
    { playlist: 2533321144, skip: ['Mark Ronson', 'The Kid Laroi', 'Will Smith', 'Pharrell Williams', 'Lil Nas X'] },
    { playlist: 1182010551, artists: ['IAM', 'MC Solaar', 'Saïan Supa Crew', 'Fonky Family', '113', 'Les Sages Poètes De La Rue'] },
    { playlist: 4676814864, artists: ['MC Solaar', "Diam's", '113', 'Psy 4 De La Rime', 'Matt', 'Cheb Mami', 'Salif'] },
  ] },
  { name: 'Dance / Disco', sources: [{ playlist: 2015058202 }, { playlist: 4699436964 }, { playlist: 4135981802 }, { playlist: 1251129741 }] },
];
export const BT_CHOICES = [...BT_PLAYLISTS.map((p) => p.name), 'Mélange'];

const listenMs = (v) => {
  const s = parseInt(String(v), 10);
  return fastTimings({ listenMs: ([15, 20, 30].includes(s) ? s : 20) * 1000 }).listenMs;
};

// 3 mauvaises réponses différentes de la bonne (et entre elles), prises dans le même groupe d'abord
export function distractors(track, pool, key) {
  const good = fold(track[key]);
  const seen = new Set([good]);
  const out = [];
  const same = shuffle(pool.filter((t) => t.group === track.group));
  const other = shuffle(pool.filter((t) => t.group !== track.group && t.kind === track.kind));
  for (const t of [...same, ...other]) {
    const f = fold(t[key]);
    // Pas deux fois le même artiste/titre, ni un faux trop proche (« Queen » / « Queen & Bowie »)
    if (!f || seen.has(f) || [...seen].some((x) => x && (f.startsWith(x + ' ') || x.startsWith(f + ' ')))) continue;
    seen.add(f);
    out.push(t[key]);
    if (out.length === 3) break;
  }
  return out;
}

export class BlindTestGame extends BaseGame {
  static id = 'blindtest';

  static async create(room, opts, hooks) {
    const n = BT.rounds.includes(opts?.rounds) ? opts.rounds : BT.defaultRounds;
    const name = BT_CHOICES.includes(opts?.playlist) ? opts.playlist : BT_CHOICES[0];
    const lists = name === 'Mélange' ? BT_PLAYLISTS : BT_PLAYLISTS.filter((p) => p.name === name);
    const sources = lists.flatMap((p) => p.sources.map((s) => ({ ...s, group: p.name })));
    // Filtre d'une source : artists = seulement ces artistes, skip = sans eux
    const allow = (t, s) => (!s.artists || s.artists.some((a) => fold(a) === fold(t.artist)))
      && !(s.skip || []).some((a) => fold(a) === fold(t.artist));
    const left = Object.fromEntries(BT_PLAYLISTS.map((p) => [p.name, p.left || 'artist']));
    // Colonne de gauche : l'artiste, ou le film (Disney)
    const pool = (await loadTracks(sources, allow))
      .map((t) => ({ ...t, kind: left[t.group], left: left[t.group] === 'film' ? cleanAlbum(t.album) : t.artist }))
      .filter((t) => t.left && t.left.length <= 40);
    if (pool.length < 8) throw new Error('Pas assez de musiques dans cette playlist pour le moment, essaie une autre');
    // Pas deux fois la même musique dans la soirée
    room.used.blindtest ??= new Set();
    let fresh = pool.filter((t) => !room.used.blindtest.has(t.id));
    if (fresh.length < n + 3) { room.used.blindtest.clear(); fresh = pool; }
    // Mélange : on alterne les playlists pour varier
    const picks = shuffle([...fresh]);
    return new BlindTestGame(room, hooks, { name, pool, picks, count: Math.min(n, picks.length), listen: listenMs(opts?.listen) });
  }

  constructor(room, hooks, { name, pool, picks, count, listen }) {
    super(room, hooks);
    this.playlist = name;
    this.pool = pool;
    this.picks = picks;          // musiques à jouer (les suivantes servent de rechange)
    this.next_ = 0;              // prochaine musique à essayer dans picks
    this.count = count;
    this.listen = listen;
    this.podiumMs = BT.podiumMs;
    this.index = -1;
    this.round = null;
    this.answers = new Map();    // pid -> { a: {v, at}, t: {v, at} }
    this.found = new Map();      // pid -> { a: n, t: n } (pour le podium)
    this.pending = null;         // manche suivante en préparation (adresse de l'extrait)
    this.askStart = 0;
    this.loading = 0;
  }

  start() {
    this.pending = this.prepare();
    this.schedule(BT.introMs, () => this.next());
  }

  stop() {
    super.stop();
    this.pending = null;
  }

  // Prochaine musique dont Deezer donne bien l'extrait (quelques essais)
  async prepare() {
    for (let tries = 0; tries < 4 && this.next_ < this.picks.length; tries++) {
      const track = this.picks[this.next_++];
      const audio = await freshPreview(track.id);
      if (this.over) return null;
      if (!audio) continue;
      const artists = shuffle([track.left, ...distractors(track, this.pool, 'left')]);
      const titles = shuffle([track.title, ...distractors(track, this.pool, 'title')]);
      if (artists.length < 4 || titles.length < 4) continue;
      return { track, audio, artists, titles, ca: artists.indexOf(track.left), ct: titles.indexOf(track.title) };
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
    this.phase = 'load';
    const seq = ++this.loading;
    // Si Deezer tarde : on attend au plus waitMs (le minuteur affiché tourne)
    this.schedule(BT.waitMs, () => this.giveUp(seq));
    this.changed();
    const started = Date.now();
    Promise.resolve(this.pending || this.prepare()).then((r) => {
      if (this.over || seq !== this.loading || this.phase !== 'load') return;
      this.pending = null;
      if (!r) return this.giveUp(seq);
      this.round = r;
      this.room.used.blindtest?.add(r.track.id);
      // Les écrans chargent l'extrait pendant loadMs (au moins 1 s une fois l'adresse connue)
      this.schedule(Math.max(BT.loadMs - (Date.now() - started), Math.round(BT.loadMs / 2.5)), () => this.ask());
      this.changed();
    }).catch((e) => { console.error('[blindtest]', e); this.giveUp(seq); });
  }

  // Plus d'extrait disponible (Deezer en panne, musiques retirées) : podium avec ce qu'on a joué
  giveUp(seq) {
    if (this.over || seq !== this.loading || this.phase !== 'load' || this.round) return;
    this.loading++;
    this.count = Math.max(0, this.index);
    this.index--;
    console.error('[blindtest] extrait introuvable, fin de la partie');
    this.podium(this.podiumMs);
  }

  ask() {
    if (this.phase !== 'load' || !this.round) return;
    this.phase = 'ask';
    this.askStart = Date.now();
    this.schedule(this.listen, () => this.reveal());
    this.changed();
  }

  reveal() {
    if (this.phase !== 'ask') return;
    this.phase = 'reveal';
    const { ca, ct } = this.round;
    for (const [pid, a] of this.answers) {
      const f = this.found.get(pid) || { a: 0, t: 0 };
      const okA = a.a?.v === ca, okT = a.t?.v === ct;
      let pts = 0;
      if (okA) { pts += this.points(a.a.at); f.a++; }
      if (okT) { pts += this.points(a.t.at); f.t++; }
      if (okA && okT) pts += BT.bothBonus;
      this.found.set(pid, f);
      if (pts) this.addPoints(pid, pts);
    }
    // On prépare déjà l'extrait suivant
    if (!this.isLast()) this.pending = this.prepare();
    this.schedule(BT.revealMs, () => (this.isLast() ? this.podium(this.podiumMs) : this.next()));
    this.changed();
  }

  points(at) {
    const speed = Math.max(0, 1 - (at - this.askStart) / this.listen);
    return BT.basePoints + Math.round((BT.speedPoints * speed) / 10) * 10;
  }

  checkAll() {
    const need = this.active();
    if (this.phase === 'ask' && need.length && need.every((p) => this.answers.get(p.pid)?.a && this.answers.get(p.pid)?.t)) {
      this.schedule(900, () => this.reveal());
    }
  }

  onMessage(p, m) {
    if (m.t === 'bt_pick') {
      if (this.phase !== 'ask' || m.r !== this.index || (m.k !== 'a' && m.k !== 't')) return;
      if (!Number.isInteger(m.choice) || m.choice < 0 || m.choice > 3) return;
      if (!this.room.players.has(p.pid)) return;
      const a = this.answers.get(p.pid) || {};
      if (a[m.k]) return; // un seul essai par colonne
      a[m.k] = { v: m.choice, at: Date.now() };
      this.answers.set(p.pid, a);
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
    const s = { ...this.base('blindtest'), index: this.index, count: this.count, playlist: this.playlist };
    const r = this.round;
    if (r && ['load', 'ask', 'reveal'].includes(this.phase)) {
      s.audio = r.audio;
      s.roundKey = `${this.index}-${r.track.id}`;
    }
    if (r && (this.phase === 'ask' || this.phase === 'reveal')) {
      s.artists = r.artists;
      s.leftLabel = r.track.kind === 'film' ? 'film' : 'artiste';
      s.titles = r.titles;
      // qui a donné quoi (jamais la réponse) : 'a', 't' ou 'at'
      s.answered = Object.fromEntries([...this.answers].map(([pid, a]) => [pid, (a.a ? 'a' : '') + (a.t ? 't' : '')]));
    }
    if (r && this.phase === 'reveal') {
      Object.assign(s, { ca: r.ca, ct: r.ct, artist: r.track.artist, film: r.track.kind === 'film' ? r.track.left : null, title: r.track.title, album: r.track.album, cover: r.track.cover });
      s.picks = Object.fromEntries([...this.answers].map(([pid, a]) => [pid, { a: a.a?.v ?? null, t: a.t?.v ?? null, ta: a.a ? a.a.at - this.askStart : null, tt: a.t ? a.t.at - this.askStart : null }]));
    }
    if (this.phase === 'podium') {
      s.found = Object.fromEntries(this.found);
      s.played = Math.max(0, this.index + 1);
    }
    return s;
  }

  playerState(pid) {
    const r = this.ranking().find((x) => x.pid === pid);
    const a = this.answers.get(pid);
    return {
      pa: a?.a?.v ?? null,
      pt: a?.t?.v ?? null,
      gain: this.phase === 'reveal' ? (this.gains.get(pid) || 0) : null,
      score: r?.score ?? 0,
      rank: r?.rank ?? null,
      players: this.ranking().length,
      found: this.found.get(pid) || { a: 0, t: 0 },
    };
  }
}
