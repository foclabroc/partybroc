// Salons PartyBroc : tout vit en mémoire (rapide pour le direct).
// La base ne garde que l'historique (soirées, pseudos, scores).
import crypto from 'node:crypto';
import { config } from './config.js';
import { db } from './db.js';
import { GAMES, gameById } from './games/index.js';

// Consonnes seulement : pas de mot gênant possible, pas de 0/O ou 1/I
const CODE_LETTERS = 'BCDFGHJKLMNPQRSTVWXZ';
const COLORS = 12;
// Équipes : 2 à 4, renommables par l'hôte (ex. « Famille Dupont »)
const TEAM_NAMES = ['Équipe Rouge', 'Équipe Bleue', 'Équipe Verte', 'Équipe Jaune'];
// Soirée enchaînée : pause entre deux jeux (classement), podium final
export const SOIREE = {
  interludeMs: process.env.PB_FAST ? 1500 : 15000,
  finalMs: process.env.PB_FAST ? 2500 : 30000,
  maxGames: 6,
};

const rid = (bytes = 8) => crypto.randomBytes(bytes).toString('hex');

function newCode(taken) {
  for (let i = 0; i < 200; i++) {
    let c = '';
    for (let j = 0; j < 4; j++) c += CODE_LETTERS[crypto.randomInt(CODE_LETTERS.length)];
    if (!taken.has(c)) return c;
  }
  throw new Error('plus de code libre');
}

// Pseudo : on enlève les caractères invisibles et les espaces en trop
export function cleanName(raw) {
  if (typeof raw !== 'string') return '';
  const s = raw.normalize('NFC')
    .replace(/[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]/gu, '')
    .replace(/\s+/g, ' ')
    .trim();
  return [...s].slice(0, 16).join('');
}

const nameKey = (n) => n.normalize('NFKD').replace(/\p{M}/gu, '').toLowerCase().replace(/\s/g, '');

function cleanEmoji(raw) {
  if (typeof raw !== 'string') return '🙂';
  const s = [...raw.trim()].slice(0, 4).join('');
  return s || '🙂';
}

// Photo de profil : JPEG, PNG ou WebP en base64, déjà réduite par l'appli
export function decodePhoto(b64) {
  if (b64 == null || b64 === '') return null;
  if (typeof b64 !== 'string' || b64.length > config.maxAvatarBytes * 1.4) throw new Error('photo trop lourde');
  const buf = Buffer.from(b64.replace(/^data:image\/\w+;base64,/, ''), 'base64');
  if (buf.length === 0 || buf.length > config.maxAvatarBytes) throw new Error('photo trop lourde');
  let type = null;
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) type = 'image/jpeg';
  else if (buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) type = 'image/png';
  else if (buf.subarray(0, 4).toString() === 'RIFF' && buf.subarray(8, 12).toString() === 'WEBP') type = 'image/webp';
  if (!type) throw new Error('format de photo inconnu');
  return { buf, type };
}

class Player {
  constructor({ name, emoji, color, photo }, pid) {
    this.pid = pid || rid(4);       // salon permanent : identifiant du membre (stable)
    this.token = rid(16);           // permet de revenir après une coupure
    this.name = name;
    this.emoji = emoji;
    this.color = color;
    this.photo = photo;             // { buf, type } ou null
    this.photoV = photo ? 1 : 0;
    this.score = 0;
    this.team = null;               // numéro d'équipe (si les équipes sont activées)
    this.ws = null;
    this.leftAt = 0;                // date de déconnexion (0 = connecté)
    this.joinedAt = Date.now();
  }

  get connected() { return this.ws !== null; }

  publicView(code) {
    return {
      pid: this.pid,
      name: this.name,
      emoji: this.emoji,
      color: this.color,
      photo: this.photo ? `/a/${code}/${this.pid}/${this.photoV}` : null,
      score: this.score,
      team: this.team,
      connected: this.connected,
    };
  }
}

export class Room {
  constructor(code, perm = false) {
    this.code = code;
    this.perm = perm;               // salon permanent (mot de passe, joueurs gardés en base)
    this.tvToken = rid(16);
    this.tvs = new Set();           // écrans connectés (la TV, et l'écran de chaque famille à distance)
    this.players = new Map();       // pid -> Player
    this.hostPid = null;
    this.phase = 'lobby';
    this.selectedGame = GAMES[0].id;
    this.createdAt = Date.now();
    this.idleSince = Date.now();
    this.maxSeen = 0;
    this.partyId = null;
    this.closed = false;
    this.game = null;               // partie en cours (instance du jeu)
    this.gameId = null;
    this.gameStartedAt = 0;
    this.starting = false;
    this.usedQuiz = new Set();      // questions déjà posées ce soir
    this.teams = { on: false, count: 2, names: [...TEAM_NAMES] };
    this.lastTeams = null;          // points de chaque équipe à la dernière partie
    this.soiree = null;             // soirée enchaînée en cours
    this.board = false;             // classement affiché sur la TV (demandé par l'hôte)
    this.boardTimer = null;
    this.chatLog = [];              // 30 derniers messages (pour qui arrive en cours)
    this.chatSeq = 0;
    this.used = {};                 // contenu déjà servi ce soir, par table (Set d'id)
    // Réglages choisis par l'hôte, par jeu
    this.options = Object.fromEntries(GAMES.map((g) => [g.id,
      Object.fromEntries(Object.entries(g.options || {}).map(([k, o]) => [k, o.def]))]));
  }

  // ---- état envoyé à tout le monde ----
  view() {
    return {
      code: this.code,
      phase: this.phase,
      perm: this.perm,
      hostPid: this.hostPid,
      tvConnected: this.tvs.size > 0,
      selectedGame: this.selectedGame,
      games: GAMES.map(({ id, title, emoji, min, ready, pitch, options }) => ({ id, title, emoji, min, ready, pitch, options: options || {} })),
      options: this.options[this.selectedGame] || {},
      game: this.game ? this.game.publicState() : null,
      teams: this.teams.on ? this.teamsView() : null,
      soiree: this.soireeView(),
      board: this.board,
      maxPlayers: config.maxPlayers,
      players: [...this.players.values()]
        .sort((a, b) => a.joinedAt - b.joinedAt)
        .map((p) => p.publicView(this.code)),
    };
  }

  broadcast() {
    const room = JSON.stringify(this.view());
    for (const tv of this.tvs) send(tv, `{"t":"room","room":${room}}`);
    for (const p of this.players.values()) {
      if (!p.ws) continue;
      // Chaque téléphone reçoit en plus son état perso dans le jeu (« you »)
      const you = this.game ? JSON.stringify(this.game.playerState(p.pid)) : 'null';
      send(p.ws, `{"t":"room","room":${room},"you":${you}}`);
    }
  }

  emit(msg, exceptPid) {
    const s = JSON.stringify(msg);
    for (const tv of this.tvs) send(tv, s);
    for (const p of this.players.values()) if (p.ws && p.pid !== exceptPid) send(p.ws, s);
  }

  sendTo(target, msg) {
    if (target === 'tv') { for (const tv of this.tvs) send(tv, msg); return; }
    const ws = this.players.get(target)?.ws;
    if (ws) send(ws, msg);
  }

  // ---- équipes ----
  teamsView() {
    const scores = Array(this.teams.count).fill(0);
    for (const p of this.players.values()) if (p.team !== null && p.team < this.teams.count) scores[p.team] += p.score;
    return {
      count: this.teams.count,
      names: this.teams.names.slice(0, this.teams.count),
      scores,
      last: this.lastTeams,
    };
  }

  // La plus petite équipe (pour placer un nouveau joueur)
  smallestTeam() {
    const n = Array(this.teams.count).fill(0);
    for (const p of this.players.values()) if (p.team !== null && p.team < this.teams.count) n[p.team]++;
    return n.indexOf(Math.min(...n));
  }

  setTeams(on, count) {
    this.teams.on = !!on;
    if (Number.isInteger(count) && count >= 2 && count <= 4) this.teams.count = count;
    for (const p of this.players.values()) {
      if (!this.teams.on) continue;
      if (p.team === null || p.team >= this.teams.count) p.team = this.smallestTeam();
    }
  }

  shuffleTeams() {
    const list = [...this.players.values()];
    for (let i = list.length - 1; i > 0; i--) {
      const j = crypto.randomInt(i + 1);
      [list[i], list[j]] = [list[j], list[i]];
    }
    list.forEach((p, i) => { p.team = i % this.teams.count; });
  }

  renameTeam(i, name) {
    if (Number.isInteger(i) && i >= 0 && i < 4 && name) this.teams.names[i] = name;
  }

  // Points de chaque équipe à cette partie
  teamTotals(results) {
    const pts = Array(this.teams.count).fill(0);
    for (const r of results || []) {
      const p = this.players.get(r.pid);
      if (p && p.team !== null && p.team < this.teams.count) pts[p.team] += r.score;
    }
    return pts;
  }

  // ---- soirée enchaînée ----
  soireeView() {
    const so = this.soiree;
    if (!so) return null;
    const ranking = [...so.scores.entries()].filter(([pid]) => this.players.has(pid))
      .map(([pid, score]) => ({ pid, score })).sort((a, b) => b.score - a.score);
    let rank = 0, prev = null;
    ranking.forEach((r, i) => { if (r.score !== prev) { rank = i + 1; prev = r.score; } r.rank = rank; });
    let teams = null;
    if (this.teams.on) {
      teams = Array(this.teams.count).fill(0);
      for (const r of ranking) {
        const p = this.players.get(r.pid);
        if (p && p.team !== null && p.team < this.teams.count) teams[p.team] += r.score;
      }
    }
    return {
      games: so.games,
      index: so.index,
      step: so.step,             // 'game' | 'interlude' | 'final'
      endsIn: Math.max(0, so.until - Date.now()),
      duration: so.duration,
      ranking,
      teams,
      last: so.last,             // dernier jeu joué (pour l'entracte)
    };
  }

  async startSoiree(list) {
    if (this.game || this.soiree) throw new Error('Une partie est déjà en cours');
    const games = [...new Set(list)].filter((id) => gameById(id)?.ready).slice(0, SOIREE.maxGames);
    if (games.length < 2) throw new Error('Choisis au moins 2 jeux pour la soirée');
    const tooFew = games.map(gameById).find((g) => this.connectedCount() < g.min);
    if (tooFew) throw new Error(`${tooFew.title} : il faut au moins ${tooFew.min} joueurs`);
    this.soiree = { games, index: 0, step: 'game', scores: new Map(), until: 0, duration: 0, last: null, timer: null };
    for (const p of this.players.values()) this.soiree.scores.set(p.pid, 0);
    this.selectedGame = games[0];
    try {
      await this.startGame();
    } catch (e) {
      this.soiree = null;
      throw e;
    }
  }

  // Après chaque jeu : entracte (classement) puis jeu suivant, ou podium final
  soireeAfterGame(results) {
    const so = this.soiree;
    for (const r of results || []) so.scores.set(r.pid, (so.scores.get(r.pid) || 0) + r.score);
    so.last = so.games[so.index];
    const last = so.index >= so.games.length - 1;
    so.step = last ? 'final' : 'interlude';
    so.duration = last ? SOIREE.finalMs : SOIREE.interludeMs;
    so.until = Date.now() + so.duration;
    clearTimeout(so.timer);
    so.timer = setTimeout(() => this.soireeNext(), so.duration);
    this.phase = so.step;
  }

  soireeFinal() {
    const so = this.soiree;
    if (!so) return;
    so.games = so.games.slice(0, so.index + 1);
    so.step = 'final';
    so.duration = SOIREE.finalMs;
    so.until = Date.now() + so.duration;
    clearTimeout(so.timer);
    so.timer = setTimeout(() => this.soireeNext(), so.duration);
    this.phase = 'final';
    this.broadcast();
  }

  async soireeNext() {
    const so = this.soiree;
    if (!so || this.closed) return;
    clearTimeout(so.timer);
    if (so.step === 'final') return this.soireeEnd();
    if (so.step !== 'interlude') return;
    // Jeu suivant (s'il ne peut pas démarrer, on passe au suivant)
    while (so.index < so.games.length - 1) {
      so.index++;
      so.step = 'game';
      this.selectedGame = so.games[so.index];
      this.phase = 'lobby';
      try {
        await this.startGame();
        return;
      } catch (e) {
        console.warn('[soirée]', so.games[so.index], e.message);
      }
    }
    this.soireeEnd();
  }

  soireeEnd() {
    const so = this.soiree;
    if (!so) return;
    clearTimeout(so.timer);
    // Salon permanent : la soirée compte aussi dans les statistiques (« soirées gagnées »)
    if (this.perm) db.statsSaved(this.code, 'soiree', this.soireeView().ranking);
    this.soiree = null;
    this.phase = 'lobby';
    this.broadcast();
  }

  // ---- parties ----
  // Classement sur la TV : affiché par l'hôte, caché par lui, au lancement d'un jeu ou au bout d'une minute
  showBoard(on) {
    clearTimeout(this.boardTimer);
    this.board = !!on;
    if (this.board) this.boardTimer = setTimeout(() => { this.board = false; this.broadcast(); }, 60_000);
  }

  async startGame() {
    const g = gameById(this.selectedGame);
    this.showBoard(false);
    if (!g || !g.ready) throw new Error(`${g?.title ?? 'Ce jeu'} arrive bientôt !`);
    if (this.game || this.starting) throw new Error('Une partie est déjà en cours');
    if (this.connectedCount() < g.min) throw new Error(`Il faut au moins ${g.min} joueurs`);
    this.starting = true;
    try {
      const game = await g.impl.create(this, this.options[g.id], {
        changed: () => { if (this.game === game) this.broadcast(); },
        finished: (results) => { if (this.game === game) this.endGame(results); },
        // Message direct (ex. traits de dessin) : à tout le monde, ou à 'tv' / un pid
        emit: (msg, except) => { if (this.game === game) this.emit(msg, except); },
        sendTo: (target, msg) => { if (this.game === game) this.sendTo(target, msg); },
      });
      if (this.closed) return;
      this.game = game;
      this.gameId = g.id;
      this.gameStartedAt = Date.now();
      this.phase = 'game';
      game.start();
      this.broadcast();
    } finally {
      this.starting = false;
    }
  }

  endGame(results) {
    if (!this.game) return;
    this.game.stop();
    // Les points de la partie s'ajoutent au score de la soirée
    for (const r of results || []) {
      const p = this.players.get(r.pid);
      if (p) p.score += r.score;
    }
    db.gameSaved(this.partyId, this.gameId, this.gameStartedAt, results || []);
    if (this.teams.on) this.lastTeams = { game: this.gameId, pts: this.teamTotals(results) };
    if (this.perm) db.statsSaved(this.code, this.gameId, results || []);
    for (const p of this.players.values()) db.playerSeen(this.partyId, p.pid, p.name, p.score);
    // Salon permanent : le score total de chaque joueur est gardé
    if (this.perm) {
      for (const r of results || []) {
        const p = this.players.get(r.pid);
        if (p) db.memberSaved(this.code, p, true);
      }
    }
    this.game = null;
    this.gameId = null;
    this.phase = 'lobby';
    if (this.soiree) this.soireeAfterGame(results);
    this.pickHost();
    this.broadcast();
  }

  connectedCount() {
    let n = 0;
    for (const p of this.players.values()) if (p.connected) n++;
    return n;
  }

  isIdle() { return this.tvs.size === 0 && this.connectedCount() === 0; }

  touch() {
    if (!this.isIdle()) this.idleSince = Date.now();
  }

  pickHost() {
    const cur = this.players.get(this.hostPid);
    if (cur && cur.connected) return;
    const next = [...this.players.values()].sort((a, b) => a.joinedAt - b.joinedAt).find((p) => p.connected);
    this.hostPid = next ? next.pid : (cur ? cur.pid : null);
  }

  // ---- joueurs ----
  nameTaken(name, exceptPid) {
    const k = nameKey(name);
    for (const p of this.players.values()) if (p.pid !== exceptPid && nameKey(p.name) === k) return true;
    return false;
  }

  addPlayer(profile, pid, score = 0) {
    if (this.players.size >= config.maxPlayers) throw new Error(`Salon complet (${config.maxPlayers} joueurs max)`);
    if (this.nameTaken(profile.name)) throw new Error('Ce pseudo est déjà pris dans ce salon');
    const p = new Player(profile, pid);
    p.score = score;
    if (this.teams.on) p.team = this.smallestTeam();
    this.players.set(p.pid, p);
    this.maxSeen = Math.max(this.maxSeen, this.players.size);
    if (!this.hostPid) this.hostPid = p.pid;
    this.game?.onPlayerJoin?.(p);
    if (this.soiree && !this.soiree.scores.has(p.pid)) this.soiree.scores.set(p.pid, 0);
    db.playerSeen(this.partyId, p.pid, p.name, 0);
    return p;
  }

  removePlayer(pid) {
    const p = this.players.get(pid);
    if (!p) return;
    this.players.delete(pid);
    if (this.hostPid === pid) this.hostPid = null;
    this.pickHost();
    this.game?.onPlayerGone?.(p);
  }

  findByToken(token) {
    if (typeof token !== 'string') return null;
    for (const p of this.players.values()) if (p.token === token) return p;
    return null;
  }

  // ---- ménage périodique ----
  sweep(now) {
    let changed = false;
    for (const p of [...this.players.values()]) {
      if (!p.connected && p.leftAt && now - p.leftAt > config.playerGraceMs && this.phase === 'lobby') {
        this.removePlayer(p.pid);
        changed = true;
      }
    }
    if (changed) this.broadcast();
  }
}

export function send(ws, data) {
  if (ws && ws.readyState === 1) ws.send(typeof data === 'string' ? data : JSON.stringify(data));
}

export class RoomManager {
  constructor() {
    this.rooms = new Map();
  }

  get(code) {
    if (typeof code !== 'string') return null;
    return this.rooms.get(code.trim().toUpperCase()) || null;
  }

  async create(permCode) {
    if (this.rooms.size >= config.maxRooms) throw new Error('Trop de salons ouverts, réessaie plus tard');
    const room = new Room(permCode || newCode(new Set(this.rooms.keys())), !!permCode);
    this.rooms.set(room.code, room);
    room.partyId = await db.partyOpened(room.code);
    console.log(`[salon] ${room.code} ouvert`);
    return room;
  }

  // Salon permanent : déjà en mémoire, ou ouvert maintenant (une seule fois même si
  // plusieurs personnes arrivent en même temps)
  async openPerm(code) {
    const cur = this.rooms.get(code);
    if (cur) return cur;
    this.opening ??= new Map();
    if (!this.opening.has(code)) {
      this.opening.set(code, this.create(code).finally(() => this.opening.delete(code)));
    }
    return this.opening.get(code);
  }

  close(room) {
    if (room.closed) return;
    room.closed = true;
    room.game?.stop();
    clearTimeout(room.soiree?.timer);
    clearTimeout(room.boardTimer);
    this.rooms.delete(room.code);
    const saves = [];
    for (const p of room.players.values()) {
      saves.push(db.playerSeen(room.partyId, p.pid, p.name, p.score));
      if (room.perm) saves.push(db.memberSaved(room.code, p));
      if (p.ws) send(p.ws, { t: 'closed' });
    }
    for (const tv of room.tvs) send(tv, { t: 'closed' });
    saves.push(db.partyClosed(room.partyId, room.maxSeen));
    console.log(`[salon] ${room.code} fermé`);
    return Promise.all(saves);
  }

  sweep() {
    const now = Date.now();
    for (const room of [...this.rooms.values()]) {
      room.sweep(now);
      if (room.isIdle() && now - room.idleSince > config.roomIdleMs) this.close(room);
    }
  }

  stats() {
    let players = 0;
    for (const r of this.rooms.values()) players += r.connectedCount();
    return { rooms: this.rooms.size, players };
  }
}

export { gameById, COLORS, cleanEmoji };
