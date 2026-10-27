// Salons PartyBroc : tout vit en mémoire (rapide pour le direct).
// La base ne garde que l'historique (soirées, pseudos, scores).
import crypto from 'node:crypto';
import { config } from './config.js';
import { db } from './db.js';
import { GAMES, gameById } from './games/index.js';

// Consonnes seulement : pas de mot gênant possible, pas de 0/O ou 1/I
const CODE_LETTERS = 'BCDFGHJKLMNPQRSTVWXZ';
const COLORS = 12;

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
  constructor({ name, emoji, color, photo }) {
    this.pid = rid(4);
    this.token = rid(16);           // permet de revenir après une coupure
    this.name = name;
    this.emoji = emoji;
    this.color = color;
    this.photo = photo;             // { buf, type } ou null
    this.photoV = photo ? 1 : 0;
    this.score = 0;
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
      connected: this.connected,
    };
  }
}

export class Room {
  constructor(code) {
    this.code = code;
    this.tvToken = rid(16);
    this.tv = null;                 // WebSocket de la TV
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
      hostPid: this.hostPid,
      tvConnected: this.tv !== null,
      selectedGame: this.selectedGame,
      games: GAMES.map(({ id, title, emoji, min, ready, pitch, options }) => ({ id, title, emoji, min, ready, pitch, options: options || {} })),
      options: this.options[this.selectedGame] || {},
      game: this.game ? this.game.publicState() : null,
      maxPlayers: config.maxPlayers,
      players: [...this.players.values()]
        .sort((a, b) => a.joinedAt - b.joinedAt)
        .map((p) => p.publicView(this.code)),
    };
  }

  broadcast() {
    const room = JSON.stringify(this.view());
    if (this.tv) send(this.tv, `{"t":"room","room":${room}}`);
    for (const p of this.players.values()) {
      if (!p.ws) continue;
      // Chaque téléphone reçoit en plus son état perso dans le jeu (« you »)
      const you = this.game ? JSON.stringify(this.game.playerState(p.pid)) : 'null';
      send(p.ws, `{"t":"room","room":${room},"you":${you}}`);
    }
  }

  emit(msg, exceptPid) {
    const s = JSON.stringify(msg);
    if (this.tv) send(this.tv, s);
    for (const p of this.players.values()) if (p.ws && p.pid !== exceptPid) send(p.ws, s);
  }

  sendTo(target, msg) {
    const ws = target === 'tv' ? this.tv : this.players.get(target)?.ws;
    if (ws) send(ws, msg);
  }

  // ---- parties ----
  async startGame() {
    const g = gameById(this.selectedGame);
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
    for (const p of this.players.values()) db.playerSeen(this.partyId, p.pid, p.name, p.score);
    this.game = null;
    this.gameId = null;
    this.phase = 'lobby';
    this.pickHost();
    this.broadcast();
  }

  connectedCount() {
    let n = 0;
    for (const p of this.players.values()) if (p.connected) n++;
    return n;
  }

  isIdle() { return this.tv === null && this.connectedCount() === 0; }

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

  addPlayer(profile) {
    if (this.players.size >= config.maxPlayers) throw new Error(`Salon complet (${config.maxPlayers} joueurs max)`);
    if (this.nameTaken(profile.name)) throw new Error('Ce pseudo est déjà pris dans ce salon');
    const p = new Player(profile);
    this.players.set(p.pid, p);
    this.maxSeen = Math.max(this.maxSeen, this.players.size);
    if (!this.hostPid) this.hostPid = p.pid;
    this.game?.onPlayerJoin?.(p);
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

  async create() {
    if (this.rooms.size >= config.maxRooms) throw new Error('Trop de salons ouverts, réessaie plus tard');
    const room = new Room(newCode(new Set(this.rooms.keys())));
    this.rooms.set(room.code, room);
    room.partyId = await db.partyOpened(room.code);
    console.log(`[salon] ${room.code} ouvert`);
    return room;
  }

  close(room) {
    if (room.closed) return;
    room.closed = true;
    room.game?.stop();
    this.rooms.delete(room.code);
    const saves = [];
    for (const p of room.players.values()) {
      saves.push(db.playerSeen(room.partyId, p.pid, p.name, p.score));
      if (p.ws) send(p.ws, { t: 'closed' });
    }
    if (room.tv) send(room.tv, { t: 'closed' });
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
