// PartyBroc : serveur HTTP (site + photos de profil) et WebSocket (/ws).
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { WebSocketServer } from 'ws';
import { config } from './config.js';
import { db } from './db.js';
import {
  RoomManager, send, cleanName, cleanEmoji, decodePhoto, gameById, COLORS,
} from './rooms.js';

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

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  if (req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405).end(); return; }

  if (url.pathname === '/health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ ok: true, db: db.enabled(), ...rooms.stats() }));
    return;
  }

  // Photo de profil : /a/CODE/pid/version
  const m = url.pathname.match(/^\/a\/([A-Z]{4})\/([0-9a-f]{8})\/\d+$/);
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
});

// ------------------------------------------------------------ WebSocket
const wss = new WebSocketServer({ server, path: '/ws', maxPayload: config.maxPayload });

function err(ws, msg, code = 'error') { send(ws, { t: 'error', code, msg }); }

function readProfile(m) {
  const name = cleanName(m.name);
  if (!name) throw new Error('Choisis un pseudo');
  const color = Number.isInteger(m.color) ? ((m.color % COLORS) + COLORS) % COLORS : 0;
  return { name, emoji: cleanEmoji(m.emoji), color, photo: decodePhoto(m.photo) };
}

// Attache une connexion à un joueur (nouvelle arrivée ou retour)
function attachPlayer(ws, room, p) {
  if (p.ws && p.ws !== ws) { send(p.ws, { t: 'replaced' }); p.ws.ctx = {}; p.ws.close(4000, 'remplacé'); }
  p.ws = ws;
  p.leftAt = 0;
  ws.ctx = { role: 'player', room, player: p };
  room.pickHost();
  room.touch();
  send(ws, { t: 'joined', code: room.code, pid: p.pid, token: p.token });
  room.broadcast();
}

const handlers = {
  // ---- TV ----
  async tv_hello(ws, m) {
    let room = rooms.get(m.code);
    if (room && room.tvToken === m.tvToken) {
      if (room.tv && room.tv !== ws) { send(room.tv, { t: 'replaced' }); room.tv.ctx = {}; room.tv.close(4000, 'remplacé'); }
    } else {
      room = await rooms.create();
    }
    room.tv = ws;
    ws.ctx = { role: 'tv', room };
    room.touch();
    send(ws, { t: 'tv_ok', code: room.code, tvToken: room.tvToken });
    room.broadcast();
  },

  tv_new(ws) {
    // La TV demande un nouveau salon : l'ancien est fermé
    const { room } = ws.ctx;
    if (room) { room.tv = null; rooms.close(room); }
    ws.ctx = {};
    return handlers.tv_hello(ws, {});
  },

  // ---- téléphones ----
  join(ws, m) {
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
    if (!p || room.hostPid !== p.pid) return;
    const g = gameById(room.selectedGame);
    if (!g.ready) return err(ws, `${g.title} arrive bientôt !`, 'not_ready');
    if (room.connectedCount() < g.min) return err(ws, `Il faut au moins ${g.min} joueurs`, 'not_enough');
    try { await room.startGame(); } catch (e) { err(ws, e.message, 'start_failed'); }
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

  ping(ws) { send(ws, { t: 'pong' }); },
};

wss.on('connection', (ws, req) => {
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
    if (role === 'tv' && room.tv === ws) room.tv = null;
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
