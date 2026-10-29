// Photos réelles des jeux (Zoom mystère, Mémoire, Le juste prix) : server/images/<dossier>/<nom>.jpg
// (photos Pixabay, téléchargées et recadrées par tools/photos_partybroc.py ; credits.csv).
// Servies sous /img/<id> avec un identifiant opaque : le nom du fichier (« chien.jpg »)
// donnerait la réponse à qui regarde le trafic du navigateur.
// Une photo absente → pas d'id → l'appli garde l'emoji.
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { config } from './config.js';

const byId = new Map();   // id -> chemin du fichier
const byKey = new Map();  // 'animaux/chien' -> id

export function slug(s) {
  return String(s).replace(/œ/g, 'oe').replace(/Œ/g, 'Oe').normalize('NFKD').replace(/\p{M}/gu, '').toLowerCase()
    .replace(/[’']/g, '-').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

export function loadImages(dir = config.imgDir) {
  byId.clear();
  byKey.clear();
  if (!fs.existsSync(dir)) return 0;
  const secret = crypto.randomBytes(8).toString('hex'); // ids différents à chaque démarrage
  for (const folder of fs.readdirSync(dir)) {
    const full = path.join(dir, folder);
    if (!fs.statSync(full).isDirectory()) continue;
    for (const f of fs.readdirSync(full)) {
      if (!/\.jpe?g$/i.test(f)) continue;
      const key = `${folder}/${f.replace(/\.jpe?g$/i, '')}`;
      const id = crypto.createHash('sha256').update(secret + key).digest('hex').slice(0, 16);
      byId.set(id, path.join(full, f));
      byKey.set(key, id);
    }
  }
  return byKey.size;
}

/** Identifiant de la photo 'dossier/nom', ou null si elle n'existe pas */
export const imgId = (key) => byKey.get(key) ?? null;

/** Fichier d'une photo d'après son identifiant (route /img/<id>) */
export const imgFile = (id) => byId.get(id) ?? null;
