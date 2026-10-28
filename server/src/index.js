// PartyBroc : serveur HTTP (site + photos de profil) et WebSocket (/ws).
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { WebSocketServer } from 'ws';
import { config } from './config.js';
import { db } from './db.js';
import {
  RoomManager, send, cleanName, cleanEmoji, decodePhoto, gameById, COLORS,
} from './rooms.js';
import {
  permCode, isPermCode, checkPassword, hashPassword, passwordOk, newToken, sha, blocked, failed, mayCreate,
} from './perm.js';

const rooms = new RoomManager();

// ------------------------------------------------------------ HTTP
const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.css': 'text/css', '.png': 'image/png', '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.wasm': 'application/wasm',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff2': 'font/woff2', '.webp': 'image/webp',
  '.frag': 'text/plain', '.bin': 'application/octet-stream', '.map': 'application/json',
};

function serveStatic(req, res, urlPath) {
  const root = path.resolve(config.webDir);
  let rel = decodeURIComponent(urlPath).replace(/\\/g, '/');
  let file = path.resolve(root, '.' + rel);
  if (!file.startsWith(root + path.sep) && file !== root) { res.writeHead(403).end(); return; }
  let st = fs.existsSync(file) ? fs.statSync(file) : null;
  // Routes de l'appli (/tv, /play…) : on renvoie index.html
  if (!st || st.isDirectory()) { file = path.join(root, 'index.html'); st = fs.existsSync(file) ? fs.statSync(file) : null; }
  if (!st) { res.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' }).end('Site non compilé (flutter build web).'); return; }
  const ext = path.extname(file).toLowerCase();
  // Les noms de fichiers ne changent pas d'une version à l'autre (main.dart.js…) : le
  // navigateur revérifie toujours (no-cache), et l'ETag lui évite de retélécharger si
  // rien n'a changé (réponse 304). Avant, max-age=1 jour gardait une vieille appli.
  const etag = `"${st.size.toString(36)}-${Math.floor(st.mtimeMs).toString(36)}"`;
  const headers = {
    'content-type': MIME[ext] || 'application/octet-stream',
    'cache-control': 'no-cache',
    etag,
    'x-content-type-options': 'nosniff',
  };
  if (req.headers['if-none-match'] === etag) { res.writeHead(304, headers).end(); return; }
  res.writeHead(200, headers);
  if (req.method === 'HEAD') { res.end(); return; }
  fs.createReadStream(file).pipe(res);
}

// Une requête bizarre (adresse mal encodée…) ne doit jamais faire tomber le serveur
const server = http.createServer((req, res) => {
  try { handleHttp(req, res); } catch (e) {
    console.warn('[http]', req.url, e.message);
    if (!res.headersSent) res.writeHead(400).end(); else res.destroy();
  }
});

function handleHttp(req, res) {
  const url = new URL(req.url, 'http://x');
  if (req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405).end(); return; }

  if (url.pathname === '/health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ ok: true, db: db.enabled(), ...rooms.stats() }));
    return;
  }

  // Photo de profil : /a/CODE/pid/version
  const m = url.pathname.match(/^\/a\/([A-Z]{4,12})\/([0-9a-f]{8})\/\d+$/);
  if (m) {
    const p = rooms.get(m[1])?.players.get(m[2]);
    if (!p || !p.photo) { res.writeHead(404).end(); return; }
    res.writeHead(200, {
      'content-type': p.photo.type,
      'cache-control': 'private, max-age=3600',
      'x-content-type-options': 'nosniff',
    });
    res.end(p.photo.buf);
    return;
  }

  serveStatic(req, res, url.pathname);
}

// ------------------------------------------------------------ WebSocket
const wss = new WebSocketServer({ server, path: '/ws', maxPayload: config.maxPayload });

// Adresse du joueur : Caddy (devant nous, en local) la met en dernier dans X-Forwarded-For
function clientIp(req) {
  const xff = req.headers['x-forwarded-for'];
  if (xff) return String(xff).split(',').pop().trim();
  return req.socket.remoteAddress || '?';
}
const connsByIp = new Map();
// Salons ouverts par une même adresse (une maison = une adresse, même avec 10 téléphones)
const roomsOpenedBy = (ip) => [...rooms.rooms.values()].filter((r) => !r.closed && r.ip === ip).length;

function err(ws, msg, code = 'error') { send(ws, { t: 'error', code, msg }); }

function readProfile(m) {
  const name = cleanName(m.name);
  if (!name) throw new Error('Choisis un pseudo');
  const color = Number.isInteger(m.color) ? ((m.color % COLORS) + COLORS) % COLORS : 0;
  return { name, emoji: cleanEmoji(m.emoji), color, photo: decodePhoto(m.photo) };
}

// Réactions proposées sur les téléphones (les autres sont refusées)
const REACTIONS = ['😂', '👏', '❤️', '😮', '🔥', '👍', '😱', '🎉'];

// Message : 80 caractères, sans caractères invisibles (sauf ceux qui assemblent les emojis)
function cleanChat(raw) {
  if (typeof raw !== 'string') return '';
  const s = raw.normalize('NFC')
    .replace(/(?!\u200d)[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]/gu, '')
    .replace(/\s+/g, ' ')
    .trim();
  return [...s].slice(0, 80).join('');
}

// n actions par période et par joueur, au-delà c'est refusé
function allow(p, kind, n, ms) {
  const now = Date.now();
  p.rate ??= {};
  const list = (p.rate[kind] || []).filter((t) => now - t < ms);
  if (list.length >= n) { p.rate[kind] = list; return false; }
  list.push(now);
  p.rate[kind] = list;
  return true;
}

// Attache une connexion à un joueur (nouvelle arrivée ou retour)
function attachPlayer(ws, room, p, extra = {}) {
  if (p.ws && p.ws !== ws) { send(p.ws, { t: 'replaced' }); p.ws.ctx = {}; p.ws.close(4000, 'remplacé'); }
  p.ws = ws;
  p.leftAt = 0;
  ws.ctx = { role: 'player', room, player: p };
  room.pickHost();
  room.touch();
  send(ws, { t: 'joined', code: room.code, pid: p.pid, token: p.token, perm: room.perm, ...extra });
  send(ws, { t: 'chat_log', items: room.chatLog });
  room.broadcast();
}

// Un écran (TV, PC de la famille…) affiche ce salon ; il quitte celui d'avant
function attachScreen(ws, room, extra = {}) {
  const old = ws.ctx?.room;
  if (old && old !== room) {
    old.tvs.delete(ws);
    if (!old.closed) { old.touch(); old.broadcast(); }
  }
  room.tvs.add(ws);
  ws.ctx = { role: 'tv', room };
  room.touch();
  send(ws, { t: 'tv_ok', code: room.code, tvToken: room.tvToken, perm: room.perm, ...extra });
  send(ws, { t: 'chat_log', items: room.chatLog });
  room.broadcast();
}

// Mot de passe d'un salon permanent, avec blocage après trop d'essais ratés
async function passwordAccepted(ws, perm, pw) {
  if (blocked(ws.ip)) throw Object.assign(new Error("Trop d'essais ratés, réessaie dans un quart d'heure"), { code: 'blocked' });
  if (await passwordOk(pw, perm.pass_hash)) return true;
  failed(ws.ip);
  return false;
}

// Salon permanent trouvé en base, ou message d'erreur déjà envoyé (renvoie null)
async function findPerm(ws, code) {
  if (!db.enabled()) { err(ws, 'Salons permanents indisponibles (pas de base)', 'no_db'); return null; }
  const perm = await db.permGet(code);
  if (perm === null) { err(ws, 'Base de données injoignable, réessaie', 'no_db'); return null; }
  if (!perm) { err(ws, 'Aucun salon avec ce nom', 'no_room'); return null; }
  return perm;
}

// Un téléphone entre dans un salon permanent : jeton gardé par le téléphone, ou mot de passe
async function permJoin(ws, code, m) {
  const live = rooms.get(code);
  const back = live?.findByToken(m.token);
  if (back) return attachPlayer(ws, live, back);
  const perm = await findPerm(ws, code);
  if (!perm) return;
  let profile;
  try { profile = readProfile(m); } catch (e) { return err(ws, e.message, 'bad_profile'); }
  const members = await db.members(code);
  if (members === null) return err(ws, 'Base de données injoignable, réessaie', 'no_db');
  let member = typeof m.mtoken === 'string' && m.mtoken ? members.find((x) => x.token_hash === sha(m.mtoken)) : null;
  if (!member) {
    if (typeof m.password !== 'string' || !m.password) return err(ws, 'Mot de passe du salon', 'need_pass');
    try {
      if (!(await passwordAccepted(ws, perm, m.password))) return err(ws, 'Mauvais mot de passe', 'bad_pass');
    } catch (e) { return err(ws, e.message, e.code || 'refused'); }
  }
  const room = await rooms.openPerm(code);
  // Pas de jeton (nouveau téléphone, cache vidé) : on retrouve le joueur à son pseudo,
  // s'il n'est pas déjà dans le salon, pour garder son score
  const key = (n) => n.normalize('NFKD').replace(/\p{M}/gu, '').toLowerCase().replace(/\s/g, '');
  if (!member) member = members.find((x) => key(x.name) === key(profile.name) && !room.players.get(x.member_id)?.connected);
  let mtoken = member && m.mtoken && member.token_hash === sha(m.mtoken) ? m.mtoken : null;
  if (!member) {
    if (members.length >= config.maxMembers) return err(ws, 'Ce salon a trop de joueurs enregistrés', 'refused');
    if (room.nameTaken(profile.name)) return err(ws, 'Ce pseudo est déjà pris dans ce salon', 'refused');
    mtoken = newToken();
    member = { member_id: crypto.randomBytes(4).toString('hex'), score: 0 };
    await db.memberCreate(code, { pid: member.member_id, ...profile, tokenHash: sha(mtoken) });
  } else if (!mtoken) {
    mtoken = newToken();
    await db.memberToken(code, member.member_id, sha(mtoken));
  }
  let p = room.players.get(member.member_id);
  if (p) {
    // Déjà dans le salon (autre onglet, retour pendant la partie) : on reprend sa place
    if (room.nameTaken(profile.name, p.pid)) return err(ws, 'Ce pseudo est déjà pris dans ce salon', 'refused');
    Object.assign(p, { name: profile.name, emoji: profile.emoji, color: profile.color });
    if (profile.photo) { p.photo = profile.photo; p.photoV++; }
  } else {
    try { p = room.addPlayer(profile, member.member_id, Number(member.score) || 0); } catch (e) { return err(ws, e.message, 'refused'); }
    console.log(`[salon] ${room.code} + ${p.name} (membre)`);
  }
  db.memberSaved(code, p);
  db.permUsed(code);
  attachPlayer(ws, room, p, { mtoken });
}

const handlers = {
  // ---- TV ----
  async tv_hello(ws, m) {
    let room = rooms.get(m.code);
    if (!room || room.tvToken !== m.tvToken) {
      if (roomsOpenedBy(ws.ip) >= config.maxRoomsPerIp) return err(ws, 'Trop de salons ouverts depuis ta connexion', 'refused');
      room = await rooms.create();
      room.ip = ws.ip;
    }
    attachScreen(ws, room);
  },

  tv_new(ws) {
    // La TV demande un nouveau salon : l'ancien est fermé (un salon permanent, lui, reste)
    const { room } = ws.ctx;
    if (room) {
      room.tvs.delete(ws);
      if (!room.perm && room.tvs.size === 0) rooms.close(room);
      else { room.touch(); room.broadcast(); }
    }
    ws.ctx = {};
    return handlers.tv_hello(ws, {});
  },

  // Créer un salon permanent (depuis un écran) : nom + mot de passe
  async perm_create(ws, m) {
    const code = permCode(m.code);
    if (!isPermCode(code)) return err(ws, 'Le nom du salon : 5 à 12 lettres', 'bad_name');
    let pw;
    try { pw = checkPassword(m.password); } catch (e) { return err(ws, e.message, 'bad_pass'); }
    if (!db.enabled()) return err(ws, 'Salons permanents indisponibles (pas de base)', 'no_db');
    const n = await db.permCount();
    if (n === null) return err(ws, 'Base de données injoignable, réessaie', 'no_db');
    if (n >= config.maxPermRooms) return err(ws, 'Trop de salons permanents', 'refused');
    if (!mayCreate(ws.ip)) return err(ws, 'Trop de salons créés, réessaie dans une heure', 'refused');
    const ok = await db.permCreate(code, await hashPassword(pw));
    if (ok === null) return err(ws, 'Base de données injoignable, réessaie', 'no_db');
    if (!ok) return err(ws, 'Ce nom de salon est déjà pris', 'name_taken');
    console.log(`[salon] ${code} créé (permanent)`);
    const key = newToken();
    await db.screenAdd(code, sha(key));
    attachScreen(ws, await rooms.openPerm(code), { key });
  },

  // Afficher un salon permanent sur cet écran : clé déjà reçue, ou mot de passe
  async perm_open(ws, m) {
    const code = permCode(m.code);
    if (!isPermCode(code)) return err(ws, 'Aucun salon avec ce nom', 'no_room');
    const perm = await findPerm(ws, code);
    if (!perm) return;
    let key = typeof m.key === 'string' && m.key && await db.screenOk(code, sha(m.key)) ? m.key : null;
    if (!key) {
      if (typeof m.password !== 'string' || !m.password) return err(ws, 'Mot de passe du salon', 'need_pass');
      try {
        if (!(await passwordAccepted(ws, perm, m.password))) return err(ws, 'Mauvais mot de passe', 'bad_pass');
      } catch (e) { return err(ws, e.message, e.code || 'refused'); }
      key = newToken();
      await db.screenAdd(code, sha(key));
    }
    db.permUsed(code);
    attachScreen(ws, await rooms.openPerm(code), { key });
  },

  // ---- téléphones ----
  join(ws, m) {
    const pc = permCode(m.code);
    if (isPermCode(pc)) return permJoin(ws, pc, m);
    const room = rooms.get(m.code);
    if (!room) return err(ws, 'Aucun salon avec ce code', 'no_room');
    const back = room.findByToken(m.token);
    if (back) return attachPlayer(ws, room, back);
    let profile;
    try { profile = readProfile(m); } catch (e) { return err(ws, e.message, 'bad_profile'); }
    let p;
    try { p = room.addPlayer(profile); } catch (e) { return err(ws, e.message, 'refused'); }
    console.log(`[salon] ${room.code} + ${p.name}`);
    attachPlayer(ws, room, p);
  },

  resume(ws, m) {
    const room = rooms.get(m.code);
    const p = room?.findByToken(m.token);
    if (!p) return err(ws, 'Ta place dans le salon a expiré', 'expired');
    attachPlayer(ws, room, p);
  },

  profile(ws, m) {
    const { room, player: p } = ws.ctx;
    if (!p) return;
    try {
      const name = m.name !== undefined ? cleanName(m.name) : p.name;
      if (!name) throw new Error('Choisis un pseudo');
      if (room.nameTaken(name, p.pid)) throw new Error('Ce pseudo est déjà pris dans ce salon');
      if (m.photo !== undefined) {
        p.photo = decodePhoto(m.photo);
        p.photoV++;
      }
      p.name = name;
      if (m.emoji !== undefined) p.emoji = cleanEmoji(m.emoji);
      if (Number.isInteger(m.color)) p.color = ((m.color % COLORS) + COLORS) % COLORS;
    } catch (e) { return err(ws, e.message, 'bad_profile'); }
    if (room.perm) db.memberSaved(room.code, p);
    send(ws, { t: 'profile_ok' });
    room.broadcast();
  },

  leave(ws) {
    const { room, player: p } = ws.ctx;
    if (!p) return;
    room.removePlayer(p.pid);
    ws.ctx = {};
    send(ws, { t: 'left' });
    room.broadcast();
  },

  // ---- hôte ----
  kick(ws, m) {
    const { room, player: p } = ws.ctx;
    if (!p || room.hostPid !== p.pid || m.pid === p.pid) return;
    const target = room.players.get(m.pid);
    if (!target) return;
    room.removePlayer(target.pid);
    if (target.ws) { send(target.ws, { t: 'kicked' }); target.ws.ctx = {}; }
    room.broadcast();
  },

  select_game(ws, m) {
    const { room, player: p } = ws.ctx;
    if (!p || room.hostPid !== p.pid || !gameById(m.game) || room.game) return;
    room.selectedGame = m.game;
    room.broadcast();
  },

  game_option(ws, m) {
    const { room, player: p } = ws.ctx;
    if (!p || room.hostPid !== p.pid || room.game) return;
    const g = gameById(room.selectedGame);
    const o = g?.options?.[m.key];
    if (!o || !o.values.includes(m.value)) return;
    room.options[g.id][m.key] = m.value;
    room.broadcast();
  },

  async start_game(ws) {
    const { room, player: p } = ws.ctx;
    if (!p || room.hostPid !== p.pid || room.soiree) return;
    const g = gameById(room.selectedGame);
    if (!g.ready) return err(ws, `${g.title} arrive bientôt !`, 'not_ready');
    if (room.connectedCount() < g.min) return err(ws, `Il faut au moins ${g.min} joueurs`, 'not_enough');
    try { await room.startGame(); } catch (e) { err(ws, e.message, 'start_failed'); }
  },

  // ---- équipes (hôte, sauf le choix de son équipe) ----
  teams_set(ws, m) {
    const { room, player: p } = ws.ctx;
    if (!p || room.hostPid !== p.pid || room.game) return;
    room.setTeams(m.on, m.count);
    room.broadcast();
  },

  teams_shuffle(ws) {
    const { room, player: p } = ws.ctx;
    if (!p || room.hostPid !== p.pid || room.game || !room.teams.on) return;
    room.shuffleTeams();
    room.broadcast();
  },

  team_name(ws, m) {
    const { room, player: p } = ws.ctx;
    if (!p || room.hostPid !== p.pid) return;
    room.renameTeam(m.i, cleanName(m.name));
    room.broadcast();
  },

  team_pick(ws, m) {
    const { room, player: p } = ws.ctx;
    if (!p || !room.teams.on || room.game) return;
    if (!Number.isInteger(m.i) || m.i < 0 || m.i >= room.teams.count) return;
    p.team = m.i;
    room.broadcast();
  },

  // ---- soirée enchaînée (hôte) ----
  async soiree_start(ws, m) {
    const { room, player: p } = ws.ctx;
    if (!p || room.hostPid !== p.pid || !Array.isArray(m.games)) return;
    try { await room.startSoiree(m.games.filter((x) => typeof x === 'string')); } catch (e) { err(ws, e.message, 'start_failed'); }
  },

  soiree_next(ws) {
    const { room, player: p } = ws.ctx;
    if (!p || room.hostPid !== p.pid || !room.soiree || room.game) return;
    room.soireeNext();
  },

  soiree_stop(ws) {
    const { room, player: p } = ws.ctx;
    if (!p || room.hostPid !== p.pid || !room.soiree) return;
    // Arrêt de la soirée : le jeu en cours s'arrête aussi (points gardés), puis podium final
    if (room.game) {
      room.soiree.games = room.soiree.games.slice(0, room.soiree.index + 1);
      room.endGame(room.game.results());
    } else {
      room.soireeFinal(); // pendant l'entracte : podium final tout de suite
    }
  },

  // ---- statistiques d'un salon permanent (écran ou joueur du salon) ----
  async perm_stats(ws) {
    const { room } = ws.ctx;
    if (!room?.perm) return;
    const st = await db.permStats(room.code);
    if (st) send(ws, { t: 'perm_stats', ...st });
  },

  // Fin de partie demandée depuis le podium ou en cours de jeu : relayé au jeu
  game_msg(ws, m) {
    const { room, player: p } = ws.ctx;
    if (!p || !room.game || !m.m || typeof m.m.t !== 'string') return;
    room.game.onMessage(p, m.m);
  },

  // La TV peut aussi parler au jeu (ex. redemander le dessin après un rechargement)
  tv_game_msg(ws, m) {
    const { role, room } = ws.ctx;
    if (role !== 'tv' || !room.game || !m.m || typeof m.m.t !== 'string') return;
    // Touche Retour de l'appli TV : partie arrêtée, retour au salon (points gardés)
    if (m.m.t === 'tv_stop') return room.endGame(room.game.results());
    room.game.onTvMessage?.(m.m);
  },

  // ---- messages et réactions en direct (téléphones → TV et tout le monde) ----
  chat(ws, m) {
    const { room, player: p } = ws.ctx;
    if (!p) return;
    const text = cleanChat(m.text);
    if (!text) return;
    if (!allow(p, 'chat', 5, 10_000)) return err(ws, 'Doucement 😅 attends un peu avant le prochain message', 'slow');
    // Dessin à deviner : pas de messages pendant qu'on devine (on soufflerait le mot)
    if (room.gameId === 'dessin' && room.game?.phase === 'draw') {
      return err(ws, 'Pas de messages pendant le dessin (ce serait de la triche 😉), les réactions oui !', 'no_chat');
    }
    const msg = { t: 'chat', id: ++room.chatSeq, pid: p.pid, name: p.name, emoji: p.emoji, color: p.color, text, at: Date.now() };
    room.chatLog.push(msg);
    if (room.chatLog.length > 30) room.chatLog.shift();
    room.emit(msg);
  },

  react(ws, m) {
    const { room, player: p } = ws.ctx;
    if (!p || !REACTIONS.includes(m.e)) return;
    if (!allow(p, 'react', 6, 2_000)) return;
    room.emit({ t: 'react', pid: p.pid, name: p.name, color: p.color, e: m.e });
  },

  ping(ws) { send(ws, { t: 'pong' }); },
};

wss.on('connection', (ws, req) => {
  ws.ip = clientIp(req);
  const n = (connsByIp.get(ws.ip) || 0) + 1;
  if (n > config.maxConnsPerIp) { ws.close(1008, 'trop de connexions'); return; }
  connsByIp.set(ws.ip, n);
  ws.on('close', () => {
    const left = (connsByIp.get(ws.ip) || 1) - 1;
    if (left > 0) connsByIp.set(ws.ip, left); else connsByIp.delete(ws.ip);
  });
  ws.ctx = {};
  ws.alive = true;
  ws.budget = { t: Date.now(), n: 0 };
  ws.on('pong', () => { ws.alive = true; });

  ws.on('message', async (data, isBinary) => {
    // Anti-flood : 40 messages par seconde max
    const now = Date.now();
    if (now - ws.budget.t > 1000) ws.budget = { t: now, n: 0 };
    if (++ws.budget.n > 40) return;
    if (isBinary) return;
    let m;
    try { m = JSON.parse(data.toString()); } catch { return; }
    if (!m || typeof m.t !== 'string' || !Object.hasOwn(handlers, m.t)) return;
    try { await handlers[m.t](ws, m); } catch (e) {
      console.warn('[ws]', m.t, e);
      err(ws, 'Erreur du serveur');
    }
  });

  ws.on('close', () => {
    const { role, room, player } = ws.ctx || {};
    if (!room || room.closed) return;
    if (role === 'tv') room.tvs.delete(ws);
    if (role === 'player' && player && player.ws === ws) {
      player.ws = null;
      player.leftAt = Date.now();
      room.pickHost();
      room.game?.onPlayerGone?.(player);
    }
    room.touch();
    room.broadcast();
  });
});

// Battement de cœur : coupe les connexions mortes (téléphone éteint…)
const beat = setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.alive) { ws.terminate(); continue; }
    ws.alive = false;
    ws.ping();
  }
  rooms.sweep();
}, 20_000);

server.listen(config.port, config.host, async () => {
  console.log(`PartyBroc sur http://${config.host}:${config.port}  (site : ${config.webDir})`);
  if (db.enabled()) console.log(`[db] ${(await db.check()) ? 'connectée' : 'INJOIGNABLE (le jeu marche quand même)'}`);
  else console.log('[db] pas de PB_DB_URL : historique désactivé');
});

async function stop() {
  clearInterval(beat);
  await Promise.all([...rooms.rooms.values()].map((r) => rooms.close(r)));
  await db.close();
  process.exit(0);
}
process.on('SIGINT', stop);
process.on('SIGTERM', stop);

export { server, rooms };
