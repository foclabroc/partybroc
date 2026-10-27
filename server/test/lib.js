// Outils communs aux tests : lancer le serveur, simuler une TV ou un téléphone.
import { spawn } from 'node:child_process';
import { WebSocket } from 'ws';

export async function startServer(port, env = {}) {
  const srv = spawn(process.execPath, ['src/index.js'], {
    env: { ...process.env, PB_PORT: String(port), ...env }, stdio: ['ignore', 'pipe', 'inherit'],
  });
  await new Promise((ok) => srv.stdout.on('data', (d) => { if (/PartyBroc sur/.test(d)) ok(); }));
  return srv;
}

export async function client(port) {
  const ws = new WebSocket(`ws://127.0.0.1:${port}/ws`);
  const inbox = [];
  const waiters = [];
  ws.on('message', (d) => {
    const m = JSON.parse(d);
    const i = waiters.findIndex((w) => w.pred(m));
    if (i >= 0) waiters.splice(i, 1)[0].ok(m); else inbox.push(m);
  });
  await new Promise((ok) => ws.on('open', ok));
  return {
    ws,
    send: (m) => ws.send(JSON.stringify(m)),
    // Attend un message qui correspond (type ou fonction) ; les plus anciens d'abord
    wait(pred, ms = 3000) {
      const f = typeof pred === 'string' ? (m) => m.t === pred : pred;
      const i = inbox.findIndex(f);
      if (i >= 0) return Promise.resolve(inbox.splice(i, 1)[0]);
      return new Promise((ok, ko) => {
        const w = { pred: f, ok };
        waiters.push(w);
        setTimeout(() => { const j = waiters.indexOf(w); if (j >= 0) { waiters.splice(j, 1); ko(new Error('délai dépassé : ' + pred)); } }, ms);
      });
    },
    // Attend un état de salon qui vérifie la condition
    room(cond, ms) { return this.wait((m) => m.t === 'room' && cond(m.room, m.you), ms); },
    flush() { inbox.length = 0; },
    close: () => ws.close(),
  };
}
